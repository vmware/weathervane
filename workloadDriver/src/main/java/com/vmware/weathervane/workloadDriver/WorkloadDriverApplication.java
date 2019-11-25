/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver;

import java.io.IOException;

import org.json.JSONException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Configuration;


@SpringBootApplication
@Configuration
public class WorkloadDriverApplication implements ApplicationRunner {
	private static final Logger logger = LoggerFactory.getLogger(WorkloadDriverApplication.class);
	
	public static void main(String[] args) throws IOException, JSONException, InterruptedException {
		SpringApplication.run(WorkloadDriverApplication.class, args);
	}

	@Override
	public void run(ApplicationArguments args) throws Exception {
		
	}
	
}
