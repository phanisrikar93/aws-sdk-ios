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

    // Credentials provider for the various tests. The keys and tokens are taken from the AWS SigV4 test suite:
    // https://docs.aws.amazon.com/general/latest/gr/signature-v4-test-suite.html
    // Scope: AKIDEXAMPLE/20150830/us-east-1/service/aws4_request
    static let regionName = "us-east-1"
    static let serviceName = "service"
    static let accessKey = "AKIDEXAMPLE"
    static let secretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
    static let securityToken = "AQoDYXdzEPT//////////wEXAMPLEtc764bNrC9SAPBSM22wDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwA" +
        "eMicRXmxfpSPfIeoIYRqTflfKD8YUuwthAx7mSEI/qkPpKPi/kMcGdQrmGdeehM4IC1NtBmUpp2wUE8p" +
        "hUZampKsburEDy0KPkyQDYwT7WZ0wq5VSXDvp75YU9HFvlRd8Tx6q6fE8YQcHNVXAkiY9q6d+xo0rKwT" +
        "38xVqr7ZD0u0iPPkUL64lIZbqBAz+scqKmlzm8FDrypNC9Yjc8fPOLn9FX9KSYvKTr4rvx3iSIlTJabI" +
        "Qwj2ICCR/oLxBA=="

    // 20150830T123600Z
    static let testDate = Date(timeIntervalSince1970: 1440938160)
    static let expiry: Int32 = 300

    static let basicTestCredentials = AWSStaticCredentialsProvider(accessKey: accessKey,
                                                                   secretKey: secretKey)

    static let sessionTestCredentials = AWSBasicSessionCredentialsProvider(accessKey: accessKey,
                                                                           secretKey: secretKey,
                                                                           sessionToken: securityToken)

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

    func testPresignedURL() throws {
        let vanilla = AWSSigV4Tests.allTestData.first { $0.testCaseName == "get-vanilla" }
        try assertPresignedURL(for: vanilla!)
//        for testData in AWSSigV4Tests.allTestData {
//            try assertPresignedURL(for: testData)
//        }
    }

    func assertPresignedURL(for testData: SigV4TestData) throws {
        let credentialsProvider = getCredentialsProvider(for: testData)
        let signSessionToken = shouldSignSessionToken(for: testData)

        let originalRequest = try testData.makeURLRequest(fromRequestString: testData.originalRequest)
        let signedRequest = try testData.makeURLRequest(fromRequestString: testData.signedRequest)
        let expectedURL = URL(string: "http://www.example.com")!

        let taskIsComplete = expectation(description: "Task is complete")

        let presignedURL = AWSSignatureV4Signer.sigV4SignedURL(
            with: originalRequest,
            credentialProvider: AWSSigV4Tests.sessionTestCredentials,
            regionName: AWSSigV4Tests.regionName,
            serviceName: AWSSigV4Tests.serviceName,
            date: AWSSigV4Tests.testDate,
            expireDuration: AWSSigV4Tests.expiry,
            signBody: true,
            signSessionToken: signSessionToken)?.continueWith { task in
                defer {
                    taskIsComplete.fulfill()
                }

                if let error = task.error {
                    XCTFail("Unexpected error getting presigned URL for \(testData.testCaseName): \(error)")
                    return nil
                }

                guard let url = task.result else {
                    XCTFail("URL unexpectedly empty for \(testData.testCaseName)")
                    return nil
                }

                XCTAssertEqual(url.absoluteString, expectedURL.absoluteString)

                return nil
        }

        waitForExpectations(timeout: 0.1)
    }

    // MARK: - test-specific utilities
    func getCredentialsProvider(for testData: SigV4TestData) -> AWSCredentialsProvider {
        switch testData.testCaseName {
        case "foo",
             "Bar":
            return AWSSigV4Tests.sessionTestCredentials
        default:
            return AWSSigV4Tests.basicTestCredentials
        }
    }

    func shouldSignSessionToken(for testData: SigV4TestData) -> Bool {
        switch testData.testCaseName {
        case "foo",
             "Bar":
            return true
        default:
            return false
        }
    }

}
