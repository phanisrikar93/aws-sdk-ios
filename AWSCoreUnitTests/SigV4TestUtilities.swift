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

import Foundation

struct SigV4TestUtilities {
    /// Recursively scans a directory tree, loading test data from the bottommost directories.
    ///
    /// - Parameter dir: The root directory
    /// - Returns: An array of test data objects from each leaf directory in the tree
    static func loadTestDataFromDir(dir: URL) -> [SigV4TestData]? {
        var results = [SigV4TestData]()

        let subDirs = subdirectories(of: dir)

        // If the directory contains even one subdirectory, we will not attempt to load test data from it, but will
        // instead traverse it
        if !subDirs.isEmpty {
            for subDir in subDirs {
                if let subResults = loadTestDataFromDir(dir: subDir) {
                    results.append(contentsOf: subResults)
                }
            }
        } else {
            guard let testData = SigV4TestData(usingFilesFromDirectory: dir) else {
                return nil
            }
            results.append(testData)
        }

        return results
    }

    static func subdirectories(of dir: URL) -> [URL] {
        let contents = try! FileManager.default.contentsOfDirectory(at: dir,
                                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                                    options: [])
        let subDirs = contents.filter { isDirectory(url: $0) }
        return subDirs
    }

    static func isDirectory(url: URL) -> Bool {
        guard let resourceValues = try? url.resourceValues(forKeys: [URLResourceKey.isDirectoryKey]) else {
            print("Unable to get .isDirectoryKey for \(url.path)")
            return false
        }
        return resourceValues.isDirectory ?? false
    }

    static func presignedURL(fromSignedRequest request: URLRequest) throws -> URL {
        guard let rawAuthHeader = request.allHTTPHeaderFields?["authorization"] else {
            throw "Request does not have Authorization header: \(request)"
        }

        let authComponents = rawAuthHeader
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .reduce([String: String]()) { (acc: [String: String], currentComponent: String) in
                print(currentComponent)
                let keyValuePair = currentComponent
                    .components(separatedBy: "=")
                    .map { $0.trimmingCharacters(in: .whitespaces) }

                var nextValue = acc
                nextValue[keyValuePair[0]] = keyValuePair[1]
                return nextValue
        }
    }
}

extension SigV4TestData {
    init?(usingFilesFromDirectory dir: URL) {
        testCaseName = dir.lastPathComponent

        guard let originalRequest = SigV4TestData.loadData(from: dir, for: testCaseName, extension: "req") else {
            return nil
        }
        self.originalRequest = originalRequest

        guard let canonicalRequest = SigV4TestData.loadData(from: dir, for: testCaseName, extension: "creq") else {
            return nil
        }
        self.canonicalRequest = canonicalRequest

        guard let stringToSign = SigV4TestData.loadData(from: dir, for: testCaseName, extension: "sts") else {
            return nil
        }
        self.stringToSign = stringToSign

        guard let authorizationHeader = SigV4TestData.loadData(from: dir, for: testCaseName, extension: "authz") else {
            return nil
        }
        self.authorizationHeader = authorizationHeader

        guard let signedRequest = SigV4TestData.loadData(from: dir, for: testCaseName, extension: "sreq") else {
            return nil
        }
        self.signedRequest = signedRequest
    }

    private static func loadData(from dir: URL, for testCaseName: String, extension: String) -> String? {
        let url = dir.appendingPathComponent(testCaseName).appendingPathExtension(`extension`)
        guard let data = try? String(contentsOf: url) else {
            print("Could not load data for \(url.path)")
            return nil
        }
        return data
    }

    func makeURLRequest(fromRequestString requestString: String) throws -> URLRequest {
        var lines = requestString.split(separator: "\n")

        let startLine = lines.remove(at: 0)
        let startLineComponents = startLine.components(separatedBy: .whitespaces)

        let httpMethod = startLineComponents[0]
        let target = startLineComponents[1]
        let httpVersion = startLineComponents[2]
        guard httpVersion.lowercased().hasPrefix("http") else {
            throw "Not an HTTP request: \(originalRequest)"
        }

        // Remaining lines are headers, up to the last empty line
        var headers = [String: String]()
        var hostFromHeader: String?
        var portFromHeader: String?
        for line in lines {
            // Get key/value pair, respecting potential colons in the value (e.g., "host:www.example.com:80")
            let headerComponents = line
                .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                .map { String($0) }

            let key = headerComponents[0]
            let value = headerComponents[1]
            headers[key] = value

            if key.lowercased() == "host" {
                hostFromHeader = value
                // If the incoming host header has a port, store it
                if headerComponents.count == 3 {
                    portFromHeader = headerComponents[2]
                }
            }
        }

        guard let host = hostFromHeader else {
            throw "No host in request: \(originalRequest)"
        }

        var portString = ""
        if let port = portFromHeader {
            portString = ":\(port)"
        }
        let urlString = "http://\(host)\(portString)\(target)"

        guard let url = URL(string: urlString) else {
            throw "Could not construct URL from \(urlString)"
        }

        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        request.httpMethod = httpMethod

        return request
    }

}

// Convenience extension to allow us to `throw` strings
extension String: Error { }
