/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 */
package com.vmware.weathervane.auction.data.dao;

import java.io.Serializable;
import java.util.List;

import com.vmware.weathervane.auction.data.model.DomainObject;

/**
 * @author Hal
 *
 */
public interface GenericDao<T extends DomainObject, ID extends Serializable> {

	public T get(ID id);
	public T getForUpdate(ID id);	
	public List<T> getAll();
	public List<T> getPage(int page, int pageSize);
	public Long getCount();
	public void save(T object);
	public T update(T object);
	public void delete(T object);
	
}
