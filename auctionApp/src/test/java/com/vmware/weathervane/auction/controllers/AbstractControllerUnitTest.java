/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.ContextHierarchy;
import org.springframework.test.context.web.WebAppConfiguration;
import org.springframework.web.context.WebApplicationContext;

/*
 * Abstract base class for all Controller Unit tests
 */
@WebAppConfiguration
@ContextHierarchy({
	@ContextConfiguration(locations= {"file:src/test/resources/controller-test-context.xml"}),
	@ContextConfiguration(locations= {"file:src/main/webapp/WEB-INF/spring/liveAuctionServlet/servlet-context.xml"})
})
public class AbstractControllerUnitTest {

	@Autowired
	protected WebApplicationContext wac;
	
	
}
