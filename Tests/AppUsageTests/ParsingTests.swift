//
//  ParsingTests.swift
//  AppUsageTests
//
//  Created by David Sherlock on 2026.
//

@testable import AppUsage
import Foundation
import Testing

struct ParsingTests {

    @Test func segbRoundTripsEntriesStatesAndTimes() {
        let payloads = [Data([1, 2, 3]), Data([4, 5, 6, 7, 8]), Data()]
        let file = SEGBWriter.file([(.written, 10, payloads[0]), (.deleted, 20, payloads[1]), (.marker, 30, payloads[2])])
        let records = SEGBParser.records(in: file)
        #expect(records.map(\.payload) == payloads)
        #expect(records.map(\.state) == [.written, .deleted, .marker])
        #expect(records.map(\.stamp) == [10, 20, 30])
        #expect(records.allSatisfy { $0.checksumMatches })
    }

    @Test func segbFlagsADamagedPayload() {
        var bytes = [UInt8](SEGBWriter.file([(.written, 1, Data([9, 9, 9, 9]))]))
        bytes[0x20 + 8] ^= 0xFF
        #expect(SEGBParser.records(in: Data(bytes)).first?.checksumMatches == false)
    }

    @Test func segbRejectsNonSEGBAndTruncatedFiles() {
        #expect(SEGBParser.records(in: Data("not a segb file at all, no.......".utf8)).isEmpty)
        #expect(SEGBParser.records(in: Data()).isEmpty)
        let file = SEGBWriter.file([(.written, 1, Data([1, 2, 3]))])
        #expect(SEGBParser.records(in: file.prefix(40)).isEmpty)
    }

    @Test func crcMatchesZlib() {
        // zlib.crc32(b"123456789") — the standard check value.
        #expect(CRC32.checksum(Array("123456789".utf8)) == 0xCBF4_3926)
    }

    @Test func protobufReadsEveryWireType() {
        let payload = SEGBWriter.screenTimePayload(bundleID: "com.example.Editor", date: Date(timeIntervalSince1970: 1_791_331_200), starting: true)
        let fields = ProtobufFields.decode(payload)
        #expect(ProtobufFields.integer(fields, 1) == 1)
        #expect(ProtobufFields.double(fields, 2) == 1_791_331_200)
        #expect(ProtobufFields.string(fields, 3) == "com.example.Editor")
        #expect(ProtobufFields.integer(fields, 5) == 1)
        #expect(ProtobufFields.decode(Data([0x0D, 1, 0, 0, 0]))[1] == [.fixed32(1)])
    }

    @Test func protobufStopsCleanlyOnTornInput() {
        let payload = SEGBWriter.screenTimePayload(bundleID: "com.example.Editor", date: Date(), starting: false)
        for cut in 0..<payload.count {
            _ = ProtobufFields.decode(payload.prefix(cut))
        }
        #expect(ProtobufFields.decode(Data([0x1A, 0x7F, 0x41])).isEmpty)
        #expect(ProtobufFields.decode(Data([0xFF])).isEmpty)
    }

    @Test func screenTimeEventDecodes() throws {
        let date = Date(timeIntervalSince1970: 1_791_331_200)
        let event = try #require(ScreenTimeDecoding.event(from: SEGBWriter.screenTimePayload(
            bundleID: "com.example.Chat", date: date, starting: false, trusted: false)))
        #expect(event == FocusEvent(bundleID: "com.example.Chat", date: date, starting: false, trusted: false))
        #expect(ScreenTimeDecoding.event(from: Data([0x08, 0x01])) == nil)
    }

    @Test func eitherClockReadsBothEpochs() {
        let date = Date(timeIntervalSince1970: 1_791_331_200)
        #expect(AppleTime.date(either: 1_791_331_200) == date)
        #expect(AppleTime.date(either: date.timeIntervalSinceReferenceDate) == date)
    }

    @Test func biomeFileNamesAndSelection() {
        let names = ["813000000000000", "813100000000000", "813200000000000", "tombstone", "lock", ""]
        #expect(BiomeFiles.creation(of: "813000000000000") == Date(timeIntervalSinceReferenceDate: 813_000_000))
        #expect(BiomeFiles.creation(of: "tombstone") == nil)
        let inSecond = DateInterval(start: Date(timeIntervalSinceReferenceDate: 813_120_000), duration: 3_600)
        #expect(BiomeFiles.relevant(names, to: inSecond, margin: 0) == ["813100000000000"])
        let atBoundary = DateInterval(start: Date(timeIntervalSinceReferenceDate: 813_199_000), duration: 3_600)
        #expect(BiomeFiles.relevant(names, to: atBoundary, margin: 1_800) == ["813100000000000", "813200000000000"])
        let past = DateInterval(start: Date(timeIntervalSinceReferenceDate: 900_000_000), duration: 60)
        #expect(BiomeFiles.relevant(names, to: past, margin: 0) == ["813200000000000"])
    }
}
