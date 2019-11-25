/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import java.util.Date;

import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.vmware.weathervane.auction.rest.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.AttendanceService;

@Controller
@RequestMapping(value = "/attendance")
public class AttendanceController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(AttendanceController.class);

	private AttendanceService attendanceService;

	@Inject
	@Named("attendanceService")
	public void setAttendanceService(AttendanceService attendanceService) {
		this.attendanceService = attendanceService;
	}

	@RequestMapping(value = "/user/{userId}", method = RequestMethod.GET)
	public @ResponseBody
	CollectionRepresentation<AttendanceRecordRepresentation> getAttendanceRecordsForUser(
			@PathVariable long userId,
			@RequestParam(value = "page", required = false) Integer page,
			@RequestParam(value = "pageSize", required = false) Integer pageSize,
			@RequestParam(value = "fromDate", required = false) Date fromDate,
			@RequestParam(value = "toDate", required = false) Date toDate,
			HttpServletResponse response) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("getAttendanceRecordsForUser userId = " + userId + ", username = " + username);
		
		// Can only get history for the authenticated user
		try {
			this.getSecurityUtil().checkAccount(userId);
		} catch (AccessDeniedException ex) {
			response.setStatus(HttpServletResponse.SC_FORBIDDEN);
			return null;	
		}

		CollectionRepresentation<AttendanceRecordRepresentation> attendanceRecordsPage = attendanceService.getAttendanceRecordsForUser(userId, fromDate, toDate, page, pageSize);
		return attendanceRecordsPage;
	}

}
