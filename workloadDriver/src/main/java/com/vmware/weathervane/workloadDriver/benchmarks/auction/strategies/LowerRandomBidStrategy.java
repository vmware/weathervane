/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies;

import java.util.Random;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LowerRandomBidStrategy implements BidStrategy {

	private static final Logger logger = LoggerFactory.getLogger(LowerRandomBidStrategy.class);

	// ToDo: The probabilities should be parameters and externally configurable
	private double bidProbability = 0.05;
	private double bidAmountIncreaseAvg = 0.02;
	private double bidAmountIncreaseStdDev = 0.02;
	private double bidAmountIncreaseMin = 0.005;
	private double bidAmountIncreaseMax = 0.06;
	private double maxBid = 1000.0; 
	
	Random randGen;
	
	public LowerRandomBidStrategy() {
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
