/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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
