--
-- Copyright 2017-2019 VMware, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Create indicies for auction tables
-- Run as auction user
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

DROP INDEX auction_auctioneer_id_idx;
DROP INDEX auction_starttime_idx;
DROP INDEX auction_state_idx;
DROP INDEX auction_current_activated_idx;

DROP INDEX highbid_preloaded_idx;
DROP INDEX highbid_bidder_id_idx;
DROP INDEX highbid_item_id_idx;
DROP INDEX highbid_auction_id_idx;
DROP INDEX highbid_state_idx;
DROP INDEX highbid_state_bidder_endtime_idx;

DROP INDEX bidcompletiondelay_bid_id_idx;
DROP INDEX bidcompletiondelay_item_id_idx;
DROP INDEX bidcompletiondelay_auction_id_idx;

DROP INDEX item_auction_id_idx;
DROP INDEX item_highbid_id_idx;
DROP INDEX item_auctioneer_id_idx;
DROP INDEX item_auction_id_id_idx;
DROP INDEX item_preloaded_idx;

DROP INDEX user_authtoken_idx;
DROP INDEX user_email_idx;

DROP INDEX keyword_keyword_idx;

DROP INDEX auction_keyword_keyword_idx;
DROP INDEX auction_keyword_auction_idx;

---
CREATE INDEX CONCURRENTLY auction_auctioneer_id_idx ON auction USING btree (auctioneer_id);
CREATE INDEX CONCURRENTLY auction_starttime_idx ON auction USING btree (starttime);
CREATE INDEX CONCURRENTLY auction_state_idx ON auction USING btree (state);
CREATE INDEX CONCURRENTLY auction_current_activated_idx ON auction USING btree (current, activated);

CREATE INDEX CONCURRENTLY highbid_preloaded_idx ON highbid USING btree (preloaded);
CREATE INDEX CONCURRENTLY highbid_bidder_id_idx ON highbid USING btree (bidder_id);
CREATE INDEX CONCURRENTLY highbid_item_id_idx ON highbid USING btree (item_id);
CREATE INDEX CONCURRENTLY highbid_auction_id_idx ON highbid USING btree (auction_id);
CREATE INDEX CONCURRENTLY highbid_state_idx ON highbid USING btree (state, id);
CREATE INDEX CONCURRENTLY highbid_state_bidder_endtime_idx ON highbid USING btree (state, bidder_id, biddingendtime);

CREATE INDEX CONCURRENTLY bidcompletiondelay_bid_id_idx ON bidcompletiondelay USING btree (bidid);
CREATE INDEX CONCURRENTLY bidcompletiondelay_item_id_idx ON bidcompletiondelay USING btree (item_id);
CREATE INDEX CONCURRENTLY bidcompletiondelay_auction_id_idx ON bidcompletiondelay USING btree (auction_id);

CREATE INDEX CONCURRENTLY item_auction_id_idx ON item USING btree (auction_id);
CREATE INDEX CONCURRENTLY item_highbid_id_idx ON item USING btree (highbid_id);
CREATE INDEX CONCURRENTLY item_auctioneer_id_idx ON item USING btree (auctioneer_id);
CREATE INDEX CONCURRENTLY item_auction_id_id_idx ON item USING btree (auction_id,id);
CREATE INDEX CONCURRENTLY item_preloaded_idx ON item USING btree (preloaded);

CREATE INDEX CONCURRENTLY user_authtoken_idx ON userdata USING btree (authtoken);
CREATE INDEX CONCURRENTLY user_email_idx ON userdata USING btree (email);

CREATE INDEX CONCURRENTLY keyword_keyword_idx ON keyword USING btree (keyword);

CREATE INDEX CONCURRENTLY auction_keyword_keyword_idx ON auction_keyword USING btree (keyword_id);
CREATE INDEX CONCURRENTLY auction_keyword_auction_idx ON auction_keyword USING btree (auction_id);

