/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies;

import java.util.Random;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class RandomBidStrategy implements BidStrategy {

	private static final Logger logger = LoggerFactory.getLogger(RandomBidStrategy.class);

	// ToDo: The probabilities should be parameters and externally configurable
	private double bidProbability = 0.2;
	private double bidAmountIncreaseAvg = 0.02;
	private double bidAmountIncreaseStdDev = 0.02;
	private double bidAmountIncreaseMin = 0.005;
	private double bidAmountIncreaseMax = 0.06;
	private double maxBid = 1000.0; 
	
	Random randGen;
	
	public RandomBidStrategy() {
		randGen = new Random();
	}
	
	
	@Override
	public boolean shouldBid(String itemName, double currentBid,
			double myCreditLimit) {
		
		double randVal = randGen.nextDouble();
		logger.debug("RandomBidStrategy:shouldBid. randval = " + randVal + " bidprobability = " + bidProbability);

		double maxNextBid = Math.round(currentBid * (1 + bidAmountIncreaseMax));
		if ((randVal <= bidProbability) && (maxNextBid < myCreditLimit) && (maxNextBid < maxBid)) {
			return true;
		} else {
			return false;
		}
	}

	@Override
	public double bidAmount(String itemName, double currentBid,
			double myCreditLimit) {

		double increasePct = (randGen.nextGaussian() * bidAmountIncreaseStdDev) + bidAmountIncreaseAvg;
		if (increasePct > bidAmountIncreaseMax) increasePct = bidAmountIncreaseMax;
		if (increasePct < bidAmountIncreaseMin) increasePct = bidAmountIncreaseMin;
		double bidAmount = currentBid + (currentBid * increasePct);

		// Make sure bid is not in fractional cents
		bidAmount = Math.round(bidAmount * 100.0) / 100.0;
		if (bidAmount <= currentBid) {
			/*
			 *  Make sure rounding didn't make bid lower than current,
			 *  which can happen for really low current
			 */
			bidAmount = currentBid + 0.01;
		}
		if (bidAmount > myCreditLimit) {
			bidAmount = myCreditLimit;
		}
		if (bidAmount > maxBid) {
			bidAmount = maxBid;
		}
				
		return bidAmount;
	}

}
