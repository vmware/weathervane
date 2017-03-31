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
package com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec;

import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.annotation.JsonSubTypes.Type;
import com.fasterxml.jackson.annotation.JsonTypeInfo.As;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsIntervalCompleteCallback;

@JsonTypeInfo(use = com.fasterxml.jackson.annotation.JsonTypeInfo.Id.NAME, include = As.PROPERTY, property = "type")
@JsonSubTypes({ @Type(value = FixedStatsIntervalSpec.class, name = "fixed"), 
	@Type(value = PeriodicStatsIntervalSpec.class, name = "periodic"),
	@Type(value = LoadPathStatsIntervalSpec.class, name = "loadpath")
})
public abstract class StatsIntervalSpec implements Runnable {
	private static final Logger logger = LoggerFactory.getLogger(StatsIntervalSpec.class);
	
	private static final ScheduledExecutorService statsExecutor;
	static {
		statsExecutor = Executors.newScheduledThreadPool(Runtime.getRuntime().availableProcessors());
		
		Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
			
			@Override
			public void run() {
				statsExecutor.shutdownNow();
			}
		}));
		
	}

	private Boolean printSummary;
	private Boolean printIntervals;
	private Boolean printCsv;
	
	@JsonIgnore
	private String name;

	@JsonIgnore
	private String curIntervalName;
	
	@JsonIgnore
	private long curIntervalStartTime;

	@JsonIgnore
	private long lastIntervalEndTime;
	
	@JsonIgnore
	private List<StatsIntervalCompleteCallback> statsIntervalCompleteCallbacks = new LinkedList<StatsIntervalCompleteCallback>();
	
	@JsonIgnore
	protected abstract long getNextInterval();

	@JsonIgnore
	private static boolean finished = false;
	
	public void initialize(String name) {
		this.name = name;
	}

	public void start() {
		long wait = this.getNextInterval();
		
		if (!finished && (wait > 0)) {
			statsExecutor.schedule(this, wait, TimeUnit.SECONDS);
		}
		
		lastIntervalEndTime = curIntervalStartTime = System.currentTimeMillis();
	}

	public static void stop() {
		finished = true;
		
		statsExecutor.shutdown();
	}
	
	@Override
	public void run() {
		lastIntervalEndTime = System.currentTimeMillis();
		
		for (StatsIntervalCompleteCallback callbackObject : statsIntervalCompleteCallbacks) {
			try {
				callbackObject.statsIntervalComplete(this);
			} catch (Throwable t) {
				System.err.println("Caught throwable when running statsIntervalComplete: " + t.toString());
				t.printStackTrace(System.err);
			}
		}

		curIntervalStartTime = lastIntervalEndTime;
		
		long wait = this.getNextInterval();
		
		if (wait > 0) {
			statsExecutor.schedule(this, wait, TimeUnit.SECONDS);
		}

	}
	
	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public Boolean getPrintSummary() {
		return printSummary;
	}

	public void setPrintSummary(Boolean printSummary) {
		this.printSummary = printSummary;
	}
	
	public Boolean getPrintIntervals() {
		return this.printIntervals;
	}

	public void setPrintIntervals(Boolean printIntervals) {
		this.printIntervals = printIntervals;
	}

	public Boolean getPrintCsv() {
		return this.printCsv;
	}

	public void setPrintCsv(Boolean printCsv) {
		this.printCsv = printCsv;
	}

	public String getCurIntervalName() {
		return curIntervalName;
	}

	public void setCurIntervalName(String curIntervalName) {
		this.curIntervalName = curIntervalName;
	}

	public long getCurIntervalStartTime() {
		return curIntervalStartTime;
	}

	public void setCurIntervalStartTime(long curIntervalStartTime) {
		this.curIntervalStartTime = curIntervalStartTime;
	}

	public long getLastIntervalEndTime() {
		return lastIntervalEndTime;
	}

	public void setLastIntervalEndTime(long lastIntervalEndTime) {
		this.lastIntervalEndTime = lastIntervalEndTime;
	}

	public boolean registerStatsIntervalCompleteCallback(StatsIntervalCompleteCallback _callbackObject) {
		return statsIntervalCompleteCallbacks.add(_callbackObject);
	}

	public boolean removeStatsIntervalCompleteCallback(StatsIntervalCompleteCallback _callbackObject) {
		return statsIntervalCompleteCallbacks.remove(_callbackObject);
	}
}
