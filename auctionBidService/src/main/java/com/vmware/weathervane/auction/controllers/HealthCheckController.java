/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

import javax.annotation.PostConstruct;
import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.ResponseStatus;

import com.fasterxml.jackson.core.JsonParseException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonMappingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.vmware.weathervane.auction.rest.representation.AuthenticationRequestRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.rest.representation.ImageInfoRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.rest.representation.UserRepresentation;


@Controller
@RequestMapping(value = "/healthCheck")
public class HealthCheckController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(HealthCheckController.class);
	
	@Inject
	@Named("jacksonObjectMapper")
	private ObjectMapper objectMapper;

	private Boolean objectMapperInitialized = false;
	
	/*
	 * This method is used to initialize the objectMapper used to 
	 * serialize and deserialize JSON.  It does mappings both mays so that the 
	 * serializers for all objects are created before server start.
	 */
	@PostConstruct
	private void initializeObjectMapper() throws JsonParseException, JsonMappingException, IOException {
		BidRepresentation aBid = objectMapper.readValue("{\"id\": \"" + UUID.randomUUID() + "\"}", BidRepresentation.class);
		String jsonString = objectMapper.writeValueAsString(aBid);
		logger.debug("Initialized BidRepresentation de/serializer: " + jsonString );
		
		ItemRepresentation anItem = objectMapper.readValue("{\"id\": 1}", ItemRepresentation.class);
		jsonString = objectMapper.writeValueAsString(anItem);
		logger.debug("Initialized ItemRepresentation de/serializer: " + jsonString );
				
		AuthenticationRequestRepresentation aRequest = objectMapper.readValue("{\"username\": \"unused\"}", AuthenticationRequestRepresentation.class);
		jsonString = objectMapper.writeValueAsString(aRequest);
		logger.debug("Initialized AuthenticationRequestRepresentation de/serializer: " + jsonString );

		UserRepresentation aUser = objectMapper.readValue("{\"username\": 1}", UserRepresentation.class);
		jsonString = objectMapper.writeValueAsString(aUser);
		logger.debug("Initialized UserRepresentation de/serializer: " + jsonString );

		CollectionRepresentation<BidRepresentation>  aBidCollection 
		= objectMapper.readValue("{\"page\" : 1, \"results\" : [{\"id\": \"" + UUID.randomUUID() + "\"}]}", 
				new TypeReference<CollectionRepresentation<BidRepresentation>>() { });
		jsonString = objectMapper.writeValueAsString(aBidCollection);
		logger.debug("Initialized CollectionRepresentation<BidRepresentation> de/serializer: " + jsonString );
	
		CollectionRepresentation<ItemRepresentation>  anItemCollection 
		= objectMapper.readValue("{\"page\" : 1, \"results\" : [{\"id\": 1}]}", 
				new TypeReference<CollectionRepresentation<ItemRepresentation>>() { });
		jsonString = objectMapper.writeValueAsString(anItemCollection);
		logger.debug("Initialized CollectionRepresentation<ItemRepresentation> de/serializer: " + jsonString );
		
		List<ImageInfoRepresentation>  anImageInfoList = objectMapper.readValue("[{\"id\": \"unused\"}]", 
						new TypeReference<List<ImageInfoRepresentation>>() { });
		jsonString = objectMapper.writeValueAsString(anImageInfoList);
		logger.debug("Initialized List<ImageInfoRepresentation> de/serializer: " + jsonString );

		objectMapperInitialized = true;
	}
	
	
	@RequestMapping(method = RequestMethod.GET)
	@ResponseStatus( HttpStatus.OK )
	@ResponseBody
	public String healthCheck() {
		logger.info("healthCheck");
		
		if (objectMapperInitialized) {
			return "alive";
		} else {
			return "initializing";
		}
		
	}
	


}
