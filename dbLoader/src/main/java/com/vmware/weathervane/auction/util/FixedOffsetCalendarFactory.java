/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.util;

import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;

import javax.annotation.PostConstruct;
import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.dao.FixedTimeOffsetDao;

/*
 * The FixedOffsetCalendarFactory is used to force Auction to 
 * believe that it is always a certain fixed date when the
 * application starts.  This simplifies the use of Auction
 * as a benchmark, since it can then always be run with the same
 * pre-loaded database state.  All locations in that application
 * and database loader that need to find the current date get  
 * their GregorianCalendar from this factory, rather than 
 * creating a new one.
 * The start date is set by configuration in the Spring container.  The
 * factory applies the offset between the simulated date and the 
 * real start time to each new GregorianCalendar before it is returned.
 */
public class FixedOffsetCalendarFactory {
	
	private static final Logger logger = LoggerFactory.getLogger(FixedOffsetCalendarFactory.class);
	
	@Inject
	@Named("fixedTimeOffsetDao")
	private FixedTimeOffsetDao fixedTimeOffsetDao;
	
	private static long offsetInMillis = 0;
	
	private static Date simulatedStartDate;
	
	public FixedOffsetCalendarFactory(Date simulatedDate) {
		
		logger.info("FixedOffsetCalendarFactory got start date " + simulatedDate.toString());
		FixedOffsetCalendarFactory.setSimulatedStartDate(simulatedDate);
	}
	
	@PostConstruct
	public void setOffset () {
		long myOffset = simulatedStartDate.getTime() -  System.currentTimeMillis();
		
		offsetInMillis = fixedTimeOffsetDao.testAndSetOffset(myOffset);
		
		logger.info("simulatedDate millis = " + simulatedStartDate.getTime() + "; current millis = " + System.currentTimeMillis() + "; offset = " + offsetInMillis);		
	}
	
	public static GregorianCalendar getCalendar() {
		GregorianCalendar retCal = new GregorianCalendar();

		// Need to add the offset to the new calendar in int sized chucks
		long offset = offsetInMillis;
		if (offset > 0) {
			while (offset > 0) {
				if (offset > Integer.MAX_VALUE) {
					retCal.add(Calendar.MILLISECOND, Integer.MAX_VALUE);
					offset -= Integer.MAX_VALUE;
				} else {
					retCal.add(Calendar.MILLISECOND, (int) offset);
					offset = 0;
				}
			}
		} else {
			while (offset < 0) {
				if (offset < Integer.MIN_VALUE) {
					retCal.add(Calendar.MILLISECOND, Integer.MIN_VALUE);
					offset += Integer.MIN_VALUE;
				} else {
					retCal.add(Calendar.MILLISECOND, (int) offset);
					offset = 0;
				}
			}
		}
		return retCal;
	}

	public static Date getSimulatedStartDate() {
		return simulatedStartDate;
	}

	public static void setSimulatedStartDate(Date simulatedStartDate) {
		FixedOffsetCalendarFactory.simulatedStartDate = simulatedStartDate;
	}
	
}
