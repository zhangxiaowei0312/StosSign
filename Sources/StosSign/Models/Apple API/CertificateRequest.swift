//
//  CertificateRequest.swift
//  StosSign
//
//  Created by Stossy11 on 19/03/2025.
//

import Foundation
import StosOpenSSL

public class CertificateRequest {
    static func generate() -> (csr: Data?, privateKey: Data?)? {
        var outputRequest: UnsafeMutablePointer<UInt8>? = nil
        var requestLength: Int = 0
        var outputPrivateKey: UnsafeMutablePointer<UInt8>? = nil
        var privateKeyLength: Int = 0

        let success = generate_certificate_request(&outputRequest, &requestLength,
                                                  &outputPrivateKey, &privateKeyLength)
        guard success == 1, let requestPointer = outputRequest, let privateKeyPointer = outputPrivateKey else {
            return nil
        }

        let csrData = Data(bytes: requestPointer, count: requestLength)
        let privateKeyData = Data(bytes: privateKeyPointer, count: privateKeyLength)

        free(requestPointer)
        free(privateKeyPointer)

        return (csrData, privateKeyData)
    }
}
