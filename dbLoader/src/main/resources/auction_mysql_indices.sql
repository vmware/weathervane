/* This script creates the schema for the Auction application
 *  when using MySQL.
 *
 * Last modified by: Hal Rosenberg
 */  

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

SHOW WARNINGS;

USE `auction` ;

ALTER TABLE userdata ADD INDEX `USER_AUTHTOKEN_IDX` (`authtoken` ASC );
ALTER TABLE userdata ADD INDEX `USER_EMAIL_IDX` (`email` ASC );

ALTER TABLE highbid ADD KEY `HIGHBID_BIDDER_ID_KEY` (`bidder_id`);
ALTER TABLE highbid ADD KEY `HIGHBID_ITEM_ID_KEY` (`item_id`);
ALTER TABLE highbid ADD KEY `HIGHBID_AUCTION_ID_KEY` (`auction_id`);
ALTER TABLE highbid ADD KEY `HIGHBID_STATE_KEY` (`state`, `id` ASC);
ALTER TABLE highbid ADD KEY `highbid_state_bidder_endtime_key` (`state`, `bidder_id`, `biddingendtime`);

ALTER TABLE item ADD KEY `ITEM_AUCTION_ID_KEY` (`auction_id`);
ALTER TABLE item ADD KEY `ITEM_AUCTION_ID_ID_KEY` (`auction_id`, `id`);
ALTER TABLE item ADD KEY `ITEM_AUCTIONEER_ID_KEY` (`auctioneer_id`);
ALTER TABLE item ADD KEY `ITEM_HIGHBID_ID_KEY` (`highbid_id`);
ALTER TABLE item ADD INDEX `ITEM_PRELOADED_IDX` (`preloaded`);

ALTER TABLE auction ADD KEY `AUCTION_AUCTIONEER_ID_KEY` (`auctioneer_id`);
ALTER TABLE auction ADD INDEX `AUCTION_STARTTIME_IDX` (`starttime` ASC);
ALTER TABLE auction ADD INDEX `AUCTION_STATE_IDX` (`state` ASC);
ALTER TABLE auction ADD INDEX `AUCTION_CURRENT_ACTIVATED_IDX` (`current` ASC, `activated` ASC);

ALTER TABLE keyword ADD INDEX `KEYWORD_KEYWORD_IDX` (`keyword` ASC);

ALTER TABLE auction_keyword ADD KEY `AUCTION_KEYWORD_KEYWORD_KEY` (`keyword_id`);
ALTER TABLE auction_keyword ADD KEY `AUCTION_KEYWORD_AUCTION_KEY` (`auction_id`);

ALTER TABLE bidcompletiondelay ADD KEY `BIDCOMPLETIONDELAY_BID_ID_KEY` (`bidid`);

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
