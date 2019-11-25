/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class AuctionAppServerWarmer {

	public static void main(String[] args) {
		SpringApplication.run(AuctionAppServerWarmer.class, args);
	}
}
