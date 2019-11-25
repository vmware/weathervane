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
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "anypassuntilhalffail")
public class AnyPassUntilHalfFailLoadPathController extends BaseLoadPathController {
	private static final Logger logger = LoggerFactory.getLogger(AnyPassUntilHalfFailLoadPathController.class);
	private boolean allMustPass = false;
	private int numPassed = 0;
	private int numFailed = 0;

	@Override
	protected boolean combineIntervalResults(boolean previousResult, boolean latestResult, boolean isLastInInverval) {
		logger.debug("combineIntervalResults previousResult = {}, " 
					+ "latestResult = {}, isLastInInverval = {}, allMustPass = {}, "
					+ "numPassed = {}, numFailed = {}",
				previousResult, latestResult, isLastInInverval, allMustPass,
				numPassed, numFailed);
		boolean combinedValue = false;
		if (allMustPass) {
			/*
			 * One we reached an interval where all have failed, then 
			 * we act like an allMustPassLoadController
			 */
			combinedValue = previousResult && latestResult;			
		} else {
			if (latestResult) {
				numPassed++;
			} else {
				numFailed++;
			}
			
			if (isLastInInverval && (numFailed >= numPassed)) {
				allMustPass = true;
				combinedValue = false;
			} else {
				combinedValue = previousResult || latestResult;							
			}
			if (isLastInInverval) {
				numPassed = 0;
				numFailed = 0;
			}
		}
		logger.debug("combineIntervalResults combinedValue = {}", combinedValue);
		return combinedValue;
	}

}
