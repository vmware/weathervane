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
package com.vmware.weathervane.auction.util;

import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;

import javax.annotation.PostConstruct;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;

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
	
	@Autowired
	@Qualifier("fixedTimeOffsetDao")
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
