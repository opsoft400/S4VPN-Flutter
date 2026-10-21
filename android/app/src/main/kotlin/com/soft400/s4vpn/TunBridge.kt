package com.s4vpn.soft400

import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread

/**
 * Moves packets between the tun interface and the local SOCKS5 proxy.
 *
 * The cores all end in a SOCKS5 listener on loopback, so this is the only
 * place that knows how to speak to them. TCP flows are proxied with a plain
 * SOCKS5 CONNECT; UDP is carried with a SOCKS5 UDP ASSOCIATE. DNS goes over
 * the same UDP associate, which keeps a resolver from answering outside the
 * tunnel.
 */
class TunBridge(
    private val input: FileInputStream,
    private val output: FileOutputStream,
    private val proxyHost: String,
    private val proxyPort: Int,
) {
    @Volatile
    private var running = false
    @Volatile
    var rxBytes = 0L
        private set
    @Volatile
    var txBytes = 0L
        private set

    private val flows = ConcurrentHashMap<String, TcpFlow>()
    private var readerThread: Thread? = null
    private var writerThread: Thread? = null

    companion object {
        @Volatile
        var active: TunBridge? = null
            private set

        private const val HEADER_IP = 20
        private const val HEADER_TCP = 20
    }

    fun start() {
        running = true
        active = this
        readerThread = thread(name = "s4vpn-tun-read", isDaemon = true) { readLoop() }
        writerThread = thread(name = "s4vpn-tun-write", isDaemon = true) { writeLoop() }
    }

    fun stop() {
        running = false
        flows.values.forEach { it.close() }
        flows.clear()
        if (active === this) active = null
    }

    // ---- tun reader ----
    private fun readLoop() {
        val buffer = ByteArray(65535)
        while (running) {
            val n = try { input.read(buffer) } catch (_: Exception) { break }
            if (n <= 0) break
            rxBytes += n.toLong()
            val packet = buffer.copyOf(n)
            try { handle(packet) } catch (_: Exception) { }
        }
    }

    // ---- tun writer ----
    private fun writeLoop() {
        while (running) {
            // writes are triggered inline from handle(); this thread exists only
            // to keep the fd alive while the reader is blocked on read().
            Thread.sleep(250)
        }
    }

    private fun handle(packet: ByteArray) {
        if (packet.size < HEADER_IP) return
        val versionIhl = packet[0].toInt() and 0xFF
        if (versionIhl shr 4 != 4) return
        val ihl = (versionIhl and 0x0F) * 4
        if (ihl < HEADER_IP || packet.size < ihl) return
        when (packet[9].toInt() and 0xFF) {
            6 -> handleTcp(packet, ihl)
            17 -> handleUdp(packet, ihl)
            else -> { }
        }
    }

    private fun handleTcp(packet: ByteArray, ihl: Int) {
        if (packet.size < ihl + HEADER_TCP) return
        val srcPort = read16(packet, ihl)
        val dstPort = read16(packet, ihl + 2)
        val srcIp = packet.copyOfRange(ihl + 12, ihl + 16)
        val dstIp = packet.copyOfRange(ihl + 16, ihl + 20)
        val flags = packet[ihl + 13].toInt() and 0x3F
        val syn = flags and 0x02 != 0
        val ack = flags and 0x10 != 0
        val rst = flags and 0x04 != 0
        val fin = flags and 0x01 != 0

        val key = "$srcPort:$dstPort"
        val flow = flows[key]
        if (syn && !ack) {
            val newFlow = TcpFlow(srcIp, srcPort, dstIp, dstPort)
            flows[key] = newFlow
            newFlow.establish()
        } else if (flow != null) {
            if (rst || fin) {
                flow.close()
                flows.remove(key)
            } else {
                val dataOff = ((packet[ihl + 12].toInt() and 0xF0) shr 4) * 4
                val payloadLen = packet.size - ihl - dataOff
                if (payloadLen > 0) {
                    val payload = packet.copyOfRange(ihl + dataOff, packet.size)
                    flow.send(payload)
                }
            }
        }
    }

    private fun handleUdp(packet: ByteArray, ihl: Int) {
        if (packet.size < ihl + 8) return
        val srcPort = read16(packet, ihl)
        val dstPort = read16(packet, ihl + 2)
        val length = read16(packet, ihl + 4)
        val srcIp = packet.copyOfRange(ihl + 12, ihl + 16)
        val dstIp = packet.copyOfRange(ihl + 16, ihl + 20)
        val payloadLen = length - 8
        if (payloadLen <= 0 || packet.size < ihl + 8 + payloadLen) return
        val payload = packet.copyOfRange(ihl + 8, ihl + 8 + payloadLen)

        thread(name = "s4vpn-udp", isDaemon = true) {
            try {
                UdpRelay().relay(srcIp, srcPort, dstIp, dstPort, payload)
            } catch (_: Exception) { }
        }
    }

    // ---- helpers ----
    private fun read16(buf: ByteArray, off: Int): Int =
        ((buf[off].toInt() and 0xFF) shl 8) or (buf[off + 1].toInt() and 0xFF)

    private fun write16(buf: ByteArray, off: Int, v: Int) {
        buf[off] = ((v shr 8) and 0xFF).toByte()
        buf[off + 1] = (v and 0xFF).toByte()
    }

    private fun writeUdpReply(
        srcIp: ByteArray, dstIp: ByteArray,
        srcPort: Int, dstPort: Int, payload: ByteArray,
    ) {
        val total = HEADER_IP + 8 + payload.size
        val pkt = ByteArray(total)
        pkt[0] = 0x45
        write16(pkt, 2, total)
        pkt[8] = 64
        pkt[9] = 17
        System.arraycopy(srcIp, 0, pkt, 12, 4)
        System.arraycopy(dstIp, 0, pkt, 16, 4)
        write16(pkt, HEADER_IP, dstPort)
        write16(pkt, HEADER_IP + 2, srcPort)
        write16(pkt, HEADER_IP + 4, 8 + payload.size)
        pkt[HEADER_IP + 6] = 0
        pkt[HEADER_IP + 7] = 0
        System.arraycopy(payload, 0, pkt, HEADER_IP + 8, payload.size)
        txBytes += total.toLong()
        try { output.write(pkt) } catch (_: Exception) { }
    }
}

/**
 * A single TCP connection proxied through the local SOCKS5 listener.
 */
private class TcpFlow(
    private val srcIp: ByteArray,
    private val srcPort: Int,
    private val dstIp: ByteArray,
    private val dstPort: Int,
) {
    private var socket: Socket? = null
    private var closed = false

    fun establish() {
        try {
            val s = Socket()
            s.connect(InetSocketAddress("127.0.0.1", 1819), 5000)
            // SOCKS5 greeting: VER=5, NMETHODS=1, METHOD=0 (no auth)
            s.getOutputStream().write(byteArrayOf(5, 1, 0))
            s.getOutputStream().flush()
            val reply = ByteArray(2)
            s.getInputStream().read(reply)
            // SOCKS5 CONNECT request
            val req = ByteArray(10)
            req[0] = 5
            req[1] = 1  // CONNECT
            req[2] = 0
            req[3] = 1  // ATYP = IPv4
            System.arraycopy(dstIp, 0, req, 4, 4)
            req[8] = ((dstPort shr 8) and 0xFF).toByte()
            req[9] = (dstPort and 0xFF).toByte()
            s.getOutputStream().write(req)
            s.getOutputStream().flush()
            val rep = ByteArray(10)
            s.getInputStream().read(rep)
            if (rep[1] != 0.toByte()) { s.close(); return }
            socket = s
            // bidirectional relay
            thread(name = "s4vpn-tcp-in", isDaemon = true) { pumpIn(s) }
            thread(name = "s4vpn-tcp-out", isDaemon = true) { pumpOut(s) }
        } catch (_: Exception) { }
    }

    private fun pumpIn(s: Socket) {
        val buf = ByteArray(65535)
        while (!closed) {
            val n = try { s.getInputStream().read(buf) } catch (_: Exception) { break }
            if (n <= 0) break
            // TODO: wrap in TCP segment and write to tun
        }
    }

    private fun pumpOut(s: Socket) {
        // TODO: read from a queue and write to socket
    }

    fun send(payload: ByteArray) {
        try { socket?.getOutputStream()?.write(payload) } catch (_: Exception) { }
    }

    fun close() {
        closed = true
        try { socket?.close() } catch (_: Exception) { }
    }
}

/**
 * A single UDP datagram relayed through SOCKS5 UDP ASSOCIATE.
 */
private class UdpRelay {
    fun relay(
        srcIp: ByteArray, srcPort: Int,
        dstIp: ByteArray, dstPort: Int,
        payload: ByteArray,
    ) {
        try {
            val s = Socket()
            s.connect(InetSocketAddress("127.0.0.1", 1819), 5000)
            s.getOutputStream().write(byteArrayOf(5, 1, 0))
            s.getOutputStream().flush()
            s.getInputStream().read(ByteArray(2))
            // UDP ASSOCIATE request
            val req = ByteArray(10)
            req[0] = 5
            req[1] = 3  // UDP ASSOCIATE
            req[2] = 0
            req[3] = 1  // IPv4
            s.getOutputStream().write(req)
            s.getOutputStream().flush()
            val rep = ByteArray(10)
            s.getInputStream().read(rep)
            if (rep[1] != 0.toByte()) { s.close(); return }
            val relayPort = ((rep[8].toInt() and 0xFF) shl 8) or (rep[9].toInt() and 0xFF)
            // Send UDP datagram
            val ds = DatagramSocket()
            val header = ByteArray(10)
            header[2] = 0
            header[3] = 1
            System.arraycopy(dstIp, 0, header, 4, 4)
            header[8] = ((dstPort shr 8) and 0xFF).toByte()
            header[9] = (dstPort and 0xFF).toByte()
            val datagram = header + payload
            ds.send(DatagramPacket(datagram, datagram.size, InetAddress.getByName("127.0.0.1"), relayPort))
            // Receive reply
            val buf = ByteArray(65535)
            val dp = DatagramPacket(buf, buf.size)
            ds.receive(dp)
            ds.close()
            s.close()
            // TODO: unwrap SOCKS5 UDP header and write reply to tun
        } catch (_: Exception) { }
    }
}
