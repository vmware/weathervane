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
	public int clearAllAuthTokens() {
		String queryString = "UPDATE User user SET user.authToken = NULL";
		logger.debug("clearAllAuthTokens queryString = " + queryString);
		Query query = entityManager.createQuery(queryString);
		return query.executeUpdate();			
	}


	@Override
	@Transactional
	public int clearAllLoggedIn() {
		String queryString = "UPDATE User user SET user.loggedin = false";
		logger.debug("clearAllLoggedIn queryString = " + queryString);
		Query query = entityManager.createQuery(queryString);
		return query.executeUpdate();			
	}

	@Override
	@Transactional
	public int resetAllCreditLimits() {
		String queryString = "UPDATE User user SET user.creditLimit = 1000000";
		logger.debug("resetAllCreditLimits queryString = " + queryString);
		Query query = entityManager.createQuery(queryString);
		return query.executeUpdate();			
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
