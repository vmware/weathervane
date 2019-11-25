/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.random;

import java.util.Random;

public class NegativeExponential {
	
	private static final Random rand = new Random();
		
	public static double getNext(double mean) {
		if (mean == 0) {
			return 0.0;
		} else {		
			return Math.log(1-rand.nextDouble())*(-mean);
		}
	}	
	
}
