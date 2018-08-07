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
auction.views.NavbarBottomHalf = Backbone.View
		.extend({

			/**
			 * Bind the events functions to the different HTML elements
			 */
			events : {
				'click .nav-link' : 'navigationClick',
			},

			/**
			 * Class constructor
			 * 
			 * @param Object
			 *            options: - el: selector for the container
			 * @return void
			 */
			initialize : function(options) {
				'use strict';
				auction.containers.navbarBottomHalf = this.$el;

				// Array that maps the ids of the links of
				// the navigation bar to the name of the page
				this.ids = {
					allAuctions : 'la-allAuctions',
					activeAuctions : 'la-activeAuctions',
					upcomingAuctions : 'la-upcomingAuctions'
				};
			},

			/**
			 * Renders the Nav Bar View
			 * 
			 * @return void
			 */
			render : function(hash) {
				'use strict';
				var hashMap = {}, i;

				if (!hash) {
					hash = auction.conf.hash.activeAuctions;
				}

				this.$el
						.html(_
								.template(
										auction.utils
												.getTemplate(auction.conf.tpls.navbarBottomHalf))
								(auction.session));

				// --------------------
				// Cache the containers of the links
				// (for the "active" display when clicking on the link)
				this.linkContainers = {};
				this.$('ul.nav.nav-top a.nav-link').each(
						_.bind(function(i, ele) {
							this.linkContainers[ele.id] = $(ele.parentNode);
						}, this));

				// Maps the different hash urls to the id of the link in the
				// navbar
				hashMap[auction.conf.hash.allAuctions] = this.ids.allAuctions;
				hashMap[auction.conf.hash.activeAuctions] = this.ids.activeAuctions;
				hashMap[auction.conf.hash.upcomingAuctions] = this.ids.upcomingAuctions;
				for (i in this.linkContainers) {
					if (hashMap[hash] === i) {
						this.linkContainers[i].addClass('active');
					} else {
						this.linkContainers[i].removeClass('active');
					}
				}
				this.$el.show();
			},

			/**
			 * Navigation Link Click Event
			 * 
			 * @return void
			 */
			navigationClick : function(evt) {
				'use strict';
				var id = evt.target.id, i;
				// Mark the proper link container as "active" and
				// remove the active display on the other links
				for (i in this.linkContainers) {
					if (i === id) {
						this.linkContainers[i].addClass('active');
					} else {
						this.linkContainers[i].removeClass('active');
					}
				}
				// Depending on the link clicked, render the corresponding page
				switch (id) {
				case this.ids.allAuctions:
					auction.instances.router.navigate(
							auction.conf.hash.allAuctions.replace(auction.conf.pageUrlKey, 0), true);
					break;
				case this.ids.upcomingAuctions:
					auction.instances.router.navigate(
							auction.conf.hash.upcomingAuctions, true);
					break;
				case this.ids.activeAuctions:
				default:
					auction.instances.router.navigate(
							auction.conf.hash.activeAuctions.replace(auction.conf.pageUrlKey, 0), true);
					break;
				}
			},
			

		});
