/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import java.util.UUID;

import javax.servlet.ServletContext;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.security.SecurityUtil;
import com.vmware.weathervane.auction.service.UserService;

/*
 * Unit Tests for UserServiceImpl
 * These tests use a mock UserDao
 */
//@RunWith(SpringJUnit4ClassRunner.class)
public class UserControllerUnitTest extends AbstractControllerUnitTest {

	@Autowired
	private UserService userService;
	
	@Autowired
	private SecurityUtil securityUtil;
	
	@Autowired
	private ServletContext servletContext;
	
	private MockMvc mockMvc;
	
	private UUID authToken;
	
	UserRepresentation existingUser;
	UserRepresentation newUser;
	UserRepresentation newUserRegistered;

	String existingUserRepresentationJson;
	String newUserRepresentationJson;

//	@SuppressWarnings("unchecked")
//	@Before
//	public void setup() throws Exception {
//		this.mockMvc = webAppContextSetup(this.wac).build();
//		
//		Mockito.when(servletContext.getServletContextName()).thenReturn("liveAuction");
//		
//		ObjectMapper jsonMapper = new ObjectMapper();
//		StringWriter jsonWriter;
//		
//		this.authToken = UUID.randomUUID();
//		existingUser = new UserRepresentation(null);
//		existingUser.setFirstname("John1");
//		existingUser.setLastname("Doe");
//		existingUser.setAuthorities("watcher");
//		existingUser.setUsername("johndoe1@foobar.xyz");
//		existingUser.setEnabled(true);
//		existingUser.setPassword("password");
//		existingUser.setState(UserState.REGISTERED);
//		existingUser.setRepeatPassword("password");
//
//		jsonWriter = new StringWriter();
//		jsonMapper.writeValue(jsonWriter, existingUser);
//		existingUserRepresentationJson = jsonWriter.toString();
//		
//		Mockito.when(userService.getUserByName("johndoe3@foobar.xyz")).thenReturn(existingUser);
//		Mockito.when(userService.getUser(1L)).thenReturn(existingUser);
//		Mockito.when(userService.getUser(99L)).thenThrow(new IndexOutOfBoundsException());
//		
//		Mockito.doNothing().when(securityUtil).checkAccount(Mockito.anyLong());
//		Mockito.doThrow(new AccessDeniedException(null)).when(securityUtil).checkAccount(2L);
//
//		newUser = new UserRepresentation(null);
//		newUser.setFirstname("John2");
//		newUser.setLastname("Doe");
//		newUser.setAuthorities("watcher");
//		newUser.setUsername("johndoe2@foobar.xyz");
//		newUser.setEnabled(true);
//		newUser.setCreditLimit(100000f);
//		newUser.setRepeatPassword("password");
//		
//		jsonWriter = new StringWriter();
//		jsonMapper.writeValue(jsonWriter, newUser);
//		newUserRepresentationJson = jsonWriter.toString();
//
//		newUserRegistered = new UserRepresentation(null);
//		newUserRegistered.setFirstname("John2");
//		newUserRegistered.setLastname("Doe");
//		newUserRegistered.setAuthorities("watcher");
//		newUserRegistered.setUsername("johndoe2@foobar.xyz");
//		newUserRegistered.setEnabled(true);
//		newUserRegistered.setCreditLimit(100000f);
//		newUserRegistered.setPassword("password");
//		newUserRegistered.setState(UserState.REGISTERED);
//
//		Mockito.when(userService.registerUser(newUser)).thenThrow(HibernateOptimisticLockingFailureException.class).thenReturn(newUserRegistered);
//		Mockito.when(userService.registerUser(existingUser)).thenThrow(DuplicateEntityException.class);
//	}
//	
//	
//	@After
//	public void verify() {
//		// Reset the mock so that it is used again. Resetting because it is
//		// container injected
//		Mockito.reset(userService);
//		Mockito.reset(securityUtil);
//	}

//	@Test
//	public void getCorrectUserProfile() throws Exception {
//		this.mockMvc
//				.perform(
//						get("/user/{id}", 1).accept(MediaType.APPLICATION_JSON))
//				.andExpect(status().isOk())
//				.andExpect(jsonPath("$.username").value("johndoe1@foobar.xyz"))
//				.andExpect(
//						header().string("Content-Type",
//								containsString("application/json")));
//
//		Mockito.verify(securityUtil, VerificationModeFactory.times(1))
//				.checkAccount(Mockito.anyLong());
//		Mockito.verify(userService, VerificationModeFactory.times(1)).getUser(
//				Mockito.anyLong());
//	}
//
//	@Test
//	public void getOtherUserProfile() throws Exception {
//		this.mockMvc.perform(
//				get("/user/{id}", 2).accept(MediaType.APPLICATION_JSON))
//				.andExpect(status().isForbidden());
//
//		Mockito.verify(securityUtil, VerificationModeFactory.times(1))
//				.checkAccount(Mockito.anyLong());
//		Mockito.verify(userService, VerificationModeFactory.times(0)).getUser(
//				Mockito.anyLong());
//	}
//
//	@Test
//	public void getUserNotFound() throws Exception {
//		this.mockMvc.perform(
//				get("/user/{id}", 99).accept(MediaType.APPLICATION_JSON))
//				.andExpect(status().isNotFound());
//
//		Mockito.verify(securityUtil, VerificationModeFactory.times(1))
//				.checkAccount(Mockito.anyLong());
//		Mockito.verify(userService, VerificationModeFactory.times(1)).getUser(
//				Mockito.anyLong());
//	}
//	
//
////	@Test
////	public void registerNewUser() throws Exception {
////		this.mockMvc
////				.perform(
////						post("/user").content(newUserRepresentationJson)
////								.accept(MediaType.APPLICATION_JSON)
////								.contentType(MediaType.APPLICATION_JSON))
////				.andExpect(status().isOk())
////				.andExpect(jsonPath("$.state").value("REGISTERED"))
////				.andExpect(
////						header().string("Content-Type",
////			containsString("application/json")));
////
////		Mockito.verify(userService, VerificationModeFactory.times(2)).registerUser(newUser);
////	}
//
//
//	@Test
//	public void registerExistingUser() throws Exception {
//		this.mockMvc
//				.perform(
//						post("/user").content(existingUserRepresentationJson)
//								.accept(MediaType.APPLICATION_JSON)
//								.contentType(MediaType.APPLICATION_JSON))
//				.andExpect(status().isConflict())
//				.andExpect(jsonPath("$.state").value(User.UserState.DUPLICATE.toString()))
//				.andExpect(
//						header().string("Content-Type",
//			containsString("application/json")));
//
//		Mockito.verify(userService, VerificationModeFactory.times(1)).registerUser(existingUser);
//	}

}
