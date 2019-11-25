/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import java.io.Serializable;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.persistence.EntityManager;
import javax.persistence.LockModeType;
import javax.persistence.PersistenceContext;
import javax.persistence.PersistenceContextType;
import javax.persistence.Query;

import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.model.DomainObject;


public class GenericDaoJpa<T extends DomainObject, ID extends Serializable> implements GenericDao<T, ID> {

	private Class<T> type;
	
	protected EntityManager entityManager;
	
	protected static final Logger logger = LoggerFactory.getLogger(GenericDaoJpa.class);
	
	@PersistenceContext(type=PersistenceContextType.TRANSACTION)
	public void setEntityManager(EntityManager entityManager) {
		this.entityManager = entityManager;
	}
	
	public GenericDaoJpa(Class<T> type) {
		super();
		this.type = type;
	}
	
	@Transactional(readOnly=true)
	public T get(ID id) {
		if (id == null) {
			return null;
		} else {
			return entityManager.find(type, id);
		}
	}

	@Transactional
	public T getForUpdate(ID id) {
		if (id == null) {
			return null;
		} else {
			return entityManager.find(type, id, LockModeType.PESSIMISTIC_WRITE);
		}
	}

	@Transactional(readOnly=true)
	public List<T> getAll() {
		return entityManager.createQuery("select o from " +
										type.getName() + " o").getResultList();
	
	}

	@Transactional(readOnly=true)
	public List<T> getPage(int page, int pageSize) {
		Query theQuery = entityManager.createQuery("select o from " +
				type.getName() + " o order by id ASC" );
		theQuery.setMaxResults(pageSize);
		theQuery.setFirstResult(page * pageSize);
		return theQuery.getResultList();
	
	}

	@Transactional
	public void save(T object) {
		entityManager.persist(object);
	}
	
	@Transactional
	public void delete(T object) {
		entityManager.remove(object);
	}

	@Transactional
	public T update(T object) {
		return entityManager.merge(object);
	}

	@Override
	@Transactional(readOnly=true)
	public Long getCount() {
		Query theQuery = entityManager.createQuery("select count(o) from " +
				type.getName() + " o" );
		return (Long) theQuery.getResultList().get(0);
	
	}
}
