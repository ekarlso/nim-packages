CREATE TABLE `packages` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(255) NOT NULL,
  `description` text,
  `license` varchar(30) NOT NULL,
  `web` varchar(255) NOT NULL,
  `maintainer` varchar(255) NOT NULL
);

CREATE TABLE `releases` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `pkg_id` int(11) NOT NULL,
  `version` varchar(255) NOT NULL,
  `method` varchar(10) NOT NULL,
  `uri` varchar(255) NOT NULL,
  CONSTRAINT `fk_releases_pkg_id`
    FOREIGN KEY (pkg_id) REFERENCES packages (`id`)
    ON DELETE CASCADE
);

CREATE TABLE `tags` (
  `pkg_id` int(11) NOT NULL PRIMARY KEY,
  `value` varchar(20) NOT NULL,
  CONSTRAINT `fk_tags_pkg_id`
    FOREIGN KEY (pkg_id) REFERENCES packages (`id`)
    ON DELETE CASCADE
)
