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
/*
 * Copyright (c) 2010, Regents of the University of California
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 *  * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *  * Neither the name of the University of California, Berkeley
 * nor the names of its contributors may be used to endorse or promote
 * products derived from this software without specific prior written
 * permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package com.vmware.weathervane.workloadDriver.common.core;

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
public class BehaviorSpec 
{	
	private static final Logger logger = LoggerFactory.getLogger(BehaviorSpec.class);
	private static Map<String, BehaviorSpec> _behaviorSpecs = new HashMap<String, BehaviorSpec>();

	public static BehaviorSpec addBehaviorSpec(String name, BehaviorSpec behaviorSpec) {
		logger.debug("addBehaviorSpec: " + behaviorSpec.toString());
		if (!behaviorSpec.isSelectionMixAvailable()) {
			behaviorSpec.normalize();
			behaviorSpec.createSelectionMatrix();
		}
		return _behaviorSpecs.put(name, behaviorSpec);
	}
	
	public static BehaviorSpec getBehaviorSpec(String name) {
		return _behaviorSpecs.get(name);
	}

	private String name;

	/**
	 * transitionDecisionClasses holds the class name of the transitionChooser for each operation
	 */
	private String[] transitionChoosers = null;

	private int initialState = 0;

	/**
	 * transitionMatrices holds an array of transition arrays, one for each operation
	 * selectionMatrices holds the cumulative probability of each state transition.
	 */
	private Double [][][] transitionMatrices = null;
	
	@JsonIgnore
	private Double [][][] selectionMatrices = null;
		
	/**
	 * asyncBehaviors holds the name of the behavior to be started asynchronously for each operation completion
	 */
	private String[] asyncBehaviors = null;
	private Integer maxNumAsyncBehaviors = 0;
	
	private Long[] meanCycleTimes = null;
	private Long[] responseTimeLimits = null;
	private Double[] responseTimeLimitsPercentile = null;
	private Double[] mixPercentage = null;
	private Double mixPercentageTolerance = 0.10;
	private Boolean[] useResponseTime = null;
	private Boolean[] isResetState = null;
	
	public BehaviorSpec( String[] transitionChoosers, Long[] meanCycleTimes, Double[][][] data, 
				Long[] responseTimeLimits, Boolean[] useResponseTime)
	{
		this.transitionChoosers = transitionChoosers.clone();
		this.meanCycleTimes = meanCycleTimes.clone();
		this.responseTimeLimits = responseTimeLimits.clone();
		this.useResponseTime = useResponseTime.clone();
		this.transitionMatrices = data.clone();
		this.normalize();
		this.createSelectionMatrix();
	}

	public BehaviorSpec( )
	{
	}

	public boolean isSelectionMixAvailable()
	{ return this.selectionMatrices != null; }
	
	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public void normalize()
	{
		for( int i = 0; i < this.transitionMatrices.length; i++ )
		{
			for (int j = 0; j < this.transitionMatrices[i].length; j++) {
				double rowSum = 0.0;
				for( int k = 0; k < this.transitionMatrices[i][j].length; k++ )
				{
					rowSum += this.transitionMatrices[i][j][k];
				}
			
				for( int k = 0; k < this.transitionMatrices[i][j].length; k++ )
				{
					this.transitionMatrices[i][j][k] /= rowSum;
				}
			}
		}
		
		if (logger.isDebugEnabled()) {
			StringBuilder matrixString = new StringBuilder();
			logger.debug("Normalized transition matrix for " + this.name + ":");
			matrixString.append("[\n");
			for( int i = 0; i < this.transitionMatrices.length; i++ ) {
				matrixString.append("  [\n");
				for (int j = 0; j < this.transitionMatrices[i].length; j++) {
					matrixString.append("    [ ");
					for( int k = 0; k < this.transitionMatrices[i][j].length; k++ )
					{
						matrixString.append(this.transitionMatrices[i][j][k] + ", ");
					}
					matrixString.append(" ],\n");;
				}
				matrixString.append("  ],\n");
			}			
			matrixString.append("],\n");
			logger.debug(matrixString.toString());
		}
	}
	
	public void createSelectionMatrix()
	{
		if( this.isSelectionMixAvailable() )
			return;
		
		this.selectionMatrices = new Double[this.transitionMatrices.length][][];
		for (int i = 0; i < this.transitionMatrices.length; i++ ) {
			this.selectionMatrices[i] = new Double[this.transitionMatrices[i].length][];
			
			for (int j = 0; j < this.transitionMatrices[i].length; j++) {
				this.selectionMatrices[i][j] = new Double[this.transitionMatrices[i][j].length];
			}
		}

		for (int i = 0; i < this.transitionMatrices.length; i++ ) {
			
			for (int j = 0; j < this.transitionMatrices[i].length; j++) {
				
				this.selectionMatrices[i][j][0] = this.transitionMatrices[i][j][0];
				for (int k = 1; k < this.transitionMatrices[i][j].length; k++) {
					this.selectionMatrices[i][j][k] = this.transitionMatrices[i][j][k] + this.selectionMatrices[i][j][k-1];
				}
			
			}
		}
		
		if (logger.isDebugEnabled()) {
			StringBuilder matrixString = new StringBuilder();
			logger.debug("selection matrix for " + this.name + ":");
			matrixString.append("[\n");
			for( int i = 0; i < this.selectionMatrices.length; i++ ) {
				matrixString.append("  [\n");
				for (int j = 0; j < this.selectionMatrices[i].length; j++) {
					matrixString.append("    [ ");;
					for( int k = 0; k < this.selectionMatrices[i][j].length; k++ )
					{
						matrixString.append(this.selectionMatrices[i][j][k] + ", ");
					}
					matrixString.append(" ],\n");;
				}
				matrixString.append("  ],\n");
			}			
			matrixString.append("],\n");
			logger.debug(matrixString.toString());
		}
	}
	
	public Double[][][] getSelectionMix()
	{
		return this.selectionMatrices;
	}
	
	public String[] getTransitionChoosers() {
		return transitionChoosers;
	}

	public void setTransitionChoosers(String[] transitionChoosers) {
		this.transitionChoosers = transitionChoosers;
	}

	public Long[] getResponseTimeLimits() {
		return responseTimeLimits.clone();
	}

	public Long getResponseTimeLimit(int i) {
		return responseTimeLimits[i];
	}

	public void setResponseTimeLimits(Long[] responseTimeLimits) {
		this.responseTimeLimits = responseTimeLimits.clone();
	}

	public Long[] getMeanCycleTimes() {
		return meanCycleTimes.clone();
	}

	public Long getMeanCycleTime(int i) {
		return meanCycleTimes[i];
	}
	
	public void setMeanCycleTimes(Long[] meanCycleTimes) {
		this.meanCycleTimes = meanCycleTimes.clone();
	}

	public Boolean getUseResponseTime(int i) {
		return useResponseTime[i];
	}

	public Boolean[] getUseResponseTime() {
		return useResponseTime;
	}

	public void setUseResponseTime(Boolean[] useResponseTime) {
		this.useResponseTime = useResponseTime;
	}

	public Double[][][] getTransitionMatrices() {
		return transitionMatrices;
		
	}
	public void setTransitionMatrices(Double[][][] transitionMatrices) {
		this.transitionMatrices = transitionMatrices.clone();
		this.normalize();
		this.createSelectionMatrix();
	}

	public String[] getAsyncBehaviors() {
		return asyncBehaviors;
	}

	public void setAsyncBehaviors(String[] asyncBehaviors) {
		this.asyncBehaviors = asyncBehaviors;
	}

	public Integer getInitialState() {
		return initialState;
	}

	public void setInitialState(Integer initialState) {
		this.initialState = initialState;
	}

	public Integer getMaxNumAsyncBehaviors() {
		return maxNumAsyncBehaviors;
	}

	public void setMaxNumAsyncBehaviors(Integer maxNumAsyncBehaviors) {
		this.maxNumAsyncBehaviors = maxNumAsyncBehaviors;
	}

	public Double getMixPercentage(int i) {
		return mixPercentage[i];
	}

	public Double[] getMixPercentage() {
		return mixPercentage;
	}

	public void setMixPercentage(Double[] mixPercentage) {
		this.mixPercentage = mixPercentage;
	}

	public Double getMixPercentageTolerance() {
		return mixPercentageTolerance;
	}

	public void setMixPercentageTolerance(Double mixPercentageTolerance) {
		this.mixPercentageTolerance = mixPercentageTolerance;
	}

	public void printMix()
	{
		for (int i = 0; i < this.transitionMatrices.length; i++ ) {
			
			for (int j = 0; j < this.transitionMatrices[i].length; j++) {
				
				for (int k = 0; k < this.transitionMatrices[i][j].length; k++) {
					System.out.print( this.transitionMatrices[i][j][k] );
	        		System.out.print( " " );

				}
				System.out.println( "" );
			}
			System.out.println( "" );
		}
		System.out.println( "" );

	}
	
	public void printSelectionMix()
	{
		for (int i = 0; i < this.selectionMatrices.length; i++ ) {
			
			for (int j = 0; j < this.selectionMatrices[i].length; j++) {
				
				for (int k = 0; k < this.selectionMatrices[i][j].length; k++) {
					System.out.print( this.selectionMatrices[i][j][k] );
	        		System.out.print( " " );

				}
				System.out.println( "" );
			}
			System.out.println( "" );
		}
		System.out.println( "" );

	}

	public Boolean[] getIsResetState() {
		return isResetState;
	}

	public void setIsResetState(Boolean[] isResetState) {
		this.isResetState = isResetState;
	}

	public Double getResponseTimeLimitPercentile(int i) {
		return responseTimeLimitsPercentile[i];
	}

	public Double[] getResponseTimeLimitsPercentile() {
		return responseTimeLimitsPercentile;
	}

	public void setResponseTimeLimitsPercentile(Double[] responseTimeLimitsPercentile) {
		this.responseTimeLimitsPercentile = responseTimeLimitsPercentile;
	}
	
	@Override
	public String toString() {
		StringBuilder out = new StringBuilder("BehaviorSpec: ");
		out.append("name = " + name);
		out.append(", initialState = " + initialState);
		out.append(", maxNumAsyncBehaviors = " + maxNumAsyncBehaviors);
		if (transitionChoosers != null) {
			out.append(", numTransitionChoosers = " + transitionChoosers.length);
		} else {
			out.append(", transitionChoosers = null");
		}
		if (transitionMatrices != null) {
			out.append(", numTransitionMatrices = " + transitionMatrices.length);
		} else {
			out.append(", transitionMatrices = null");
		}
		if (asyncBehaviors != null) {
			out.append(", numAsyncBehaviors = " + asyncBehaviors.length);
		} else {
			out.append(", asyncBehaviors = null");
		}
		return out.toString();
	}
	
}
