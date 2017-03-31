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
package com.vmware.weathervane.auction.controllers;

import java.util.UUID;

import javax.servlet.ServletContext;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.security.SecurityUtil;
import com.vmware.weathervane.auction.service.ItemService;

/*
 * Unit Tests for UserServiceImpl
 * These tests use a mock UserDao
 */
//@RunWith(SpringJUnit4ClassRunner.class)
public class ItemControllerUnitTest extends AbstractControllerUnitTest {

	@Autowired
	private ItemService itemService;
	
	@Autowired
	private SecurityUtil securityUtil;
	
	@Autowired
	private ServletContext servletContext;
	
	private MockMvc mockMvc;
	
	private UUID authToken;
	
	User existingUser;
	User newUser;
	User newUserRegistered;

	UserRepresentation existingLiveUser;
	UserRepresentation newLiveUser;

	String existingLiveUserJson;
	String newLiveUserJson;

//	@SuppressWarnings("unchecked")
//	@Before
//	public void setup() throws Exception {
//		this.mockMvc = webAppContextSetup(this.wac).build();
//		Mockito.when(servletContext.getServletContextName()).thenReturn("liveAuction");
//
//	}
//	
//	
//	@After
//	public void verify() {
//		// Reset the mock so that it is used again. Resetting because it is
//		// container injected
//		Mockito.reset(itemService);
//		Mockito.reset(securityUtil);
//	}

//	@Test
//	public void getSingleItem() throws Exception {
//	}
//
//	@Test
//	public void getNonExistentItem() throws Exception {
//	}
//
//	@Test
//	public void getItemsForAuction() throws Exception {
//	}
//
//	@Test
//	public void getItemsForEmptyAuction() throws Exception {
//	}
//
//	@Test
//	public void getItemsForNonexistentAuction() throws Exception {
//	}
//
//	@Test
//	public void getCurrentItemForAuction() throws Exception {
//	}
//
//	@Test
//	public void getCurrentItemForEmptyAuction() throws Exception {
//	}
//
//	@Test
//	public void getCurrentItemForNonexistentAuction() throws Exception {
//	}
//	
//	@Test
//	public void getPurchasedItemsForUser() throws Exception {
//		
//	}
//	
//	@Test
//	public void getPurchasedItemsForUserWithNone() throws Exception {
//		
//	}
//	
//	@Test
//	public void getPurchasedItemsForUserFromDate() throws Exception {
//		
//	}
//	
//	@Test
//	public void getPurchasedItemsForUserToDate() throws Exception {
//		
//	}
//	
//	@Test
//	public void getPurchasedItemsForUserFromDateToDate() throws Exception {
//		
//	}
//	
//	@Test
//	public void getPurchasedItemsForNonauthorizedUser() throws Exception {
//		
//	}
	

}
