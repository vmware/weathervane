/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.random;

import java.util.Random;

public class TruncatedNormal {
	
	private static final Random rand = new Random();
		
	public static double getNext(double mean, double stddev, double min, double max) {
		double rVal;
		do {
			rVal = rand.nextGaussian()*stddev + mean;
		} while ((rVal < min) || (rVal > max));
		return rVal;
	}		
}
