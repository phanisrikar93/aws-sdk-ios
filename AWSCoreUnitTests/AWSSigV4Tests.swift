//
// Copyright 2010-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
// http://aws.amazon.com/apache2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

import XCTest

import AWSCore

/// Tests the signer using the standard SigV4 test suite
/// (https://docs.aws.amazon.com/general/latest/gr/signature-v4-test-suite.html), plus some extra tests to cover cases
/// not included in that suite.
///
/// To refresh the suite, download from the above URL, extract the ZIP archive, and copy it into the AWSCoreUnitTests
/// directory as-is. This class' setUp method will load the test suites into a bundle for execution
class AWSSigV4Tests: XCTestCase {

    static var allTestData = [SigV4TestData]()

    override static func setUp() {
        loadDataFromStandardSuite()
        loadDataFromMobileSDKSuite()
    }

    /// Loads test data from the standard AWS Test suite
    static func loadDataFromStandardSuite() {
        let testSuiteDir = Bundle(for: self)
            .resourceURL!
            .appendingPathComponent("aws-sig-v4-test-suite")
            .appendingPathComponent("aws-sig-v4-test-suite")

        guard let results = SigV4TestUtilities.loadTestDataFromDir(dir: testSuiteDir) else {
            print("Could not find test data in \(testSuiteDir.path)")
            return
        }

        allTestData.append(contentsOf: results)
    }

    /// Loads test data from the AWS Mobile SDK suite
    static func loadDataFromMobileSDKSuite() {
        let testSuiteDir = Bundle(for: self)
            .resourceURL!
            .appendingPathComponent("aws-mobile-sdk-test-suite")

        guard let results = SigV4TestUtilities.loadTestDataFromDir(dir: testSuiteDir) else {
            print("Could not find test data in \(testSuiteDir.path)")
            return
        }

        allTestData.append(contentsOf: results)
    }

    // MARK: - Tests

    func testAllCases() {
        XCTFail("Not yet implemented")
        for testData in AWSSigV4Tests.allTestData {
            assertSigV4(for: testData)
        }
    }

    func assertSigV4(for testData: SigV4TestData) {

    }

}

struct SigV4TestData {
    let testCaseName: String
    let originalRequest: String
    let canonicalRequest: String
    let stringToSign: String
    let authorizationHeader: String
    let signedRequest: String
}
