/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.common;

public class AuctionConstants {
   public static final long INTRA_LOGIN_TRY_WAIT_MILLIS = 1000;
   public static final String USER_PASSWORD = "password";
   public static final int DEFAULT_PAGE_SIZE = 5;
   
   public static final int DEFAULT_USERS_SCALE_FACTOR = 5;  // There are SCALE_FACTOR * users Users in the DB
   public static final int DEFAULT_USERS_PER_AUCTION = 15;
}
