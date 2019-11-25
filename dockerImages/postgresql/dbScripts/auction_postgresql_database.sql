--
-- Copyright 2017-2019 VMware, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Run as a non-auction user
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

DROP DATABASE IF EXISTS auction;
CREATE DATABASE auction OWNER auction;
