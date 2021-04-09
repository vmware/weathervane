--
-- Copyright 2017-2019 VMware, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Run as auction user
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;


--
-- Name: auction_keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY auction_keyword DROP CONSTRAINT auction_keyword_pkey ;
ALTER TABLE ONLY auction_keyword
    ADD CONSTRAINT auction_keyword_pkey PRIMARY KEY (auction_id, keyword_id);


--
-- Name: auction_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY auction DROPD CONSTRAINT auction_pkey;
ALTER TABLE ONLY auction
    ADD CONSTRAINT auction_pkey PRIMARY KEY (id);

--
-- Name: highbid_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY highbid DROP CONSTRAINT highbid_pkey;
ALTER TABLE ONLY highbid
    ADD CONSTRAINT highbid_pkey PRIMARY KEY (id);


--
-- Name: bidcompletiondelay_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY bidcompletiondelay DROP CONSTRAINT bidcompletiondelay_pkey;
ALTER TABLE ONLY bidcompletiondelay
    ADD CONSTRAINT bidcompletiondelay_pkey PRIMARY KEY (id);

    
--
-- Name: fixedtimeoffset_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY fixedtimeoffset DROP CONSTRAINT fixedtimeoffset_pkey;
ALTER TABLE ONLY fixedtimeoffset
    ADD CONSTRAINT fixedtimeoffset_pkey PRIMARY KEY (id);


--
-- Name: item_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY item DROP CONSTRAINT item_pkey;
ALTER TABLE ONLY item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- Name: keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY keyword DROP CONSTRAINT keyword_pkey;
ALTER TABLE ONLY keyword
    ADD CONSTRAINT keyword_pkey PRIMARY KEY (id);


--
-- Name: userdata_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY userdata DROP CONSTRAINT userdata_pkey;
ALTER TABLE ONLY userdata
    ADD CONSTRAINT userdata_pkey PRIMARY KEY (id);

--
-- Name: dbbenchmarkinfo_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY dbbenchmarkinfo DROP CONSTRAINT dbbenchmarkinfo_pkey;
ALTER TABLE ONLY dbbenchmarkinfo
    ADD CONSTRAINT dbbenchmarkinfo_pkey PRIMARY KEY (id);

--
-- Name: userdata_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY auctionmgmt DROP CONSTRAINT auctionmgmt_pkey;
ALTER TABLE ONLY auctionmgmt
    ADD CONSTRAINT auctionmgmt_pkey PRIMARY KEY (id);
    
--
-- Name: hibernate_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY hibernate_sequences DROP CONSTRAINT hibernate_sequences_pkey;
ALTER TABLE ONLY hibernate_sequences
    ADD CONSTRAINT hibernate_sequences_pkey PRIMARY KEY (sequence_name);

