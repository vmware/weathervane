/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import net.sf.ehcache.CacheException;
import net.sf.ehcache.Ehcache;
import net.sf.ehcache.Element;
import net.sf.ehcache.event.CacheEventListener;

public class AuthTokenCacheEventListener implements CacheEventListener {
	private static final Logger logger = LoggerFactory.getLogger(AuthTokenCacheEventListener.class);


	@Override
	public void notifyElementRemoved(Ehcache cache, Element element) throws CacheException {
		logger.debug("Element removed from " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyElementPut(Ehcache cache, Element element) throws CacheException {
		logger.debug("Element put in " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyElementUpdated(Ehcache cache, Element element) throws CacheException {
		logger.debug("Element updated in " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyElementExpired(Ehcache cache, Element element) {
		logger.debug("Element expired in " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyElementEvicted(Ehcache cache, Element element) {
		logger.debug("Element evicted in " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyRemoveAll(Ehcache cache) {
		logger.debug("Remove all on cache " + cache.getName() );		
	}

	@Override
	public void dispose() {
	}
	
	@Override
	public Object clone(){
	    throw new UnsupportedOperationException("Not supported yet.");
	  }

}
