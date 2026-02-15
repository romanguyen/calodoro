import XCTest
@testable import Calodoro

final class TimeFormatterTests: XCTestCase {
  func testFormatsMinutesAndSeconds() {
    XCTAssertEqual(TimeFormatter.string(from: 65), "01:05")
  }

  func testFormatsHoursWhenNeeded() {
    XCTAssertEqual(TimeFormatter.string(from: 3661), "01:01:01")
  }
}
