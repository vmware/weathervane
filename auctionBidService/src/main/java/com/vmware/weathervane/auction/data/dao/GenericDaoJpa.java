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
