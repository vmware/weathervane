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
package com.vmware.weathervane.workloadDriver.benchmarks.auction.common;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class AuctionValueGenerator {
	private static final Logger logger = LoggerFactory.getLogger(AuctionValueGenerator.class);

	private static final String FIRSTNAME="John";
	private static final String LASTNAME="Doe";
	private static final String PASSWORD="password";
	private static final String DOMAIN="foobar.xyz";
		
	Random ranGen = new Random();
	
	public AuctionValueGenerator() {


	}
	
	/**
	 * This generates the usernames and associated passwords for all of the users that will
	 * be in the database for this run.  This needs to be changed if the database loader
	 * for the application is changed.
	 * 
	 * @author hrosenbe
	 * @param numberOfUsers
	 */
	public static Map<String, String> generateUsers(int numberOfUsers, int usersScaleFactor) {
		logger.info("AuctionValueGenerator::generateUsers numberOfUsers=" + numberOfUsers + " Scale factor = " + usersScaleFactor);
		Map<String, String> users = new HashMap<String, String>();
		for (int j = 0; j < numberOfUsers * usersScaleFactor; j++) {
				users.put(FIRSTNAME.toLowerCase() + LASTNAME.toLowerCase() + j + "@" + DOMAIN, PASSWORD);
		}
		return users;
	}

	public static Map<String, String> generateUsers(int startUserId, int numberOfUsers, List<String> userNameList) {
		int maxUserId = startUserId + numberOfUsers - 1;
		logger.info("AuctionValueGenerator::generateUsers startUserId = " + startUserId + 
				", numberOfUsers=" + numberOfUsers + ", last userId = " + maxUserId );
		Map<String, String> users = new HashMap<String, String>();
		for (int j = startUserId; j <= maxUserId; j++) {
				String username = FIRSTNAME.toLowerCase() + LASTNAME.toLowerCase() + j + "@" + DOMAIN;
				userNameList.add(username);
				users.put(username, PASSWORD);
		}
		return users;
	}
}
