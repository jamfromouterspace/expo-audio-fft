//
//  TempiUtilities.swift
//  TempiBeatDetection
//
//  Created by John Scalo on 1/8/16.
//  Copyright © 2016 John Scalo. See accompanying License.txt for terms.

import Foundation
import Accelerate

func tempi_is_power_of_2 (n: Int) -> Bool {
    let lg2 = logbf(Float(n))
    return remainderf(Float(n), powf(2.0, lg2)) == 0
}
