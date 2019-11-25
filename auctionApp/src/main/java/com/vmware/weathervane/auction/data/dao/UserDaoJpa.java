/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import java.util.List;

import javax.persistence.NoResultException;
import javax.persistence.Query;

import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.model.User;

@Repository("userDao")
public class UserDaoJpa extends GenericDaoJpa<User, Long> implements UserDao {

	public UserDaoJpa() {
		super(User.class);
		
		logger.info("UserDaoJpa constructor");
	}

	@Override
	@Transactional(readOnly=true)
	public User getUserByName(String username) {

		String queryString = "SELECT user FROM User user WHERE user.email = :name";
		Query query = entityManager.createQuery(queryString);
		query.setParameter("name", username);

		return (User) query.getSingleResult();					
	}

	@Override
	@Transactional(readOnly=true)
	public List<User> getLoggedInUsers() {
		
		String queryString = "SELECT user FROM User user WHERE user.authToken IS NOT NULL";
		Query query = entityManager.createQuery(queryString);
		return query.getResultList();			
	}

	@Override
	@Transactional(readOnly=true)
	public User getUserByAuthToken(String authToken) {
		
		String queryString = "SELECT user FROM User user WHERE user.authToken = :authToken";
		Query query = entityManager.createQuery(queryString);
		query.setParameter("authToken", authToken);
		query.setHint("org.hibernate.cacheable", true);
		
		try {
			return (User) query.getSingleResult();			
		} catch (NoResultException ex) {
			return null;
		}
		
	}

	@Override
	@Transactional
	public User updateUser(User updateUser) {
		User userToUpdate  = this.get(updateUser.getId());
		
		if ((updateUser.getAuthorities() != null) && (!updateUser.getAuthorities().equals(""))
				&& (!updateUser.getAuthorities().equals(userToUpdate.getAuthorities()))) {
			userToUpdate.setAuthorities(updateUser.getAuthorities());
		}
		
		if ((updateUser.getCreditLimit() != null) && (updateUser.getCreditLimit() != 0)
				&& (!updateUser.getCreditLimit().equals(userToUpdate.getCreditLimit()))) {
			userToUpdate.setCreditLimit(updateUser.getCreditLimit());
		}

		if ((updateUser.getFirstname() != null) && (!updateUser.getFirstname().equals(""))
				&& (!updateUser.getFirstname().equals(userToUpdate.getFirstname()))) {
			userToUpdate.setFirstname(updateUser.getFirstname());
		}

		if ((updateUser.getLastname() != null) && (!updateUser.getLastname().equals(""))
				&& (!updateUser.getLastname().equals(userToUpdate.getLastname()))) {
			userToUpdate.setLastname(updateUser.getLastname());
		}

		if ((updateUser.getEmail() != null) && (!updateUser.getEmail().equals(""))
				&& (!updateUser.getEmail().equals(userToUpdate.getEmail()))) {
			logger.info("updateUser: Updating email. old =  " + userToUpdate.getEmail() + ", new = " + updateUser.getEmail());
			userToUpdate.setEmail(updateUser.getEmail());
		}

		if ((updateUser.getPassword() != null) && (!updateUser.getPassword().equals(""))
				&& (!updateUser.getPassword().equals(userToUpdate.getPassword()))) {
			userToUpdate.setPassword(updateUser.getPassword());
		}

		return userToUpdate;
	}

}
