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

ALTER TABLE highbid ADD CONSTRAINT `BID_AUCTION_ID_FK` FOREIGN KEY (`auction_id` ) REFERENCES `auction`.`auction` (`id` );
ALTER TABLE highbid ADD CONSTRAINT `BID_ITEM_ID_FK` FOREIGN KEY (`item_id` ) REFERENCES `auction`.`item` (`id` );
ALTER TABLE highbid ADD CONSTRAINT `BID_BIDDER_ID_FK` FOREIGN KEY (`bidder_id` ) REFERENCES `auction`.`userdata` (`id` );

ALTER TABLE item ADD CONSTRAINT `ITEM_HIGHBID_ID_FK`
    FOREIGN KEY (`highbid_id` )
    REFERENCES `auction`.`highbid` (`id` );
ALTER TABLE item ADD CONSTRAINT `ITEM_AUCTION_ID_FK`
    FOREIGN KEY (`auction_id` )
    REFERENCES `auction`.`auction` (`id` );
ALTER TABLE item ADD CONSTRAINT `ITEM_AUCTIONEER_ID_FK` 
    FOREIGN KEY (`auctioneer_id`) 
    REFERENCES `auction`.`userdata` (`id`);

ALTER TABLE bidcompletiondelay ADD CONSTRAINT `BCD_AUCTION_ID_FK`
    FOREIGN KEY (`auction_id` )
    REFERENCES `auction`.`auction` (`id` );
ALTER TABLE bidcompletiondelay ADD CONSTRAINT `BCD_ITEM_ID_FK`
    FOREIGN KEY (`item_id` )
    REFERENCES `auction`.`item` (`id` );

ALTER TABLE auction ADD CONSTRAINT `AUCTION_AUCTIONEER_ID_FK`
    FOREIGN KEY (`auctioneer_id` )
    REFERENCES `auction`.`userdata` (`id` );

ALTER TABLE auction_keyword ADD CONSTRAINT `AUCTION_ID_FK`
    FOREIGN KEY (`auction_id` )
    REFERENCES `auction`.`auction` (`id` );
ALTER TABLE auction_keyword ADD CONSTRAINT `KEYWORD_ID_FK`
    FOREIGN KEY (`keyword_id` )
    REFERENCES `auction`.`keyword` (`id` );

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
