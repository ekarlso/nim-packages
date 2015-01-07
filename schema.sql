CREATE TABLE packages (
    id          INTEGER         PRIMARY KEY AUTOINCREMENT
                                NOT NULL,
    license     VARCHAR(50)     NOT NULL,
    name        VARCHAR(100)    NOT NULL,
    description TEXT,
    web         TEXT            NOT NULL,
    maintainer  TEXT            NOT NULL,
    FOREIGN KEY ( license )
        REFERENCES licenses ( name )
);

CREATE TABLE releases (
    id      INTEGER PRIMARY KEY AUTOINCREMENT
                    NOT NULL,
    pkg_id  INTEGER NOT NULL,
    version TEXT    NOT NULL,
    method  TEXT    NOT NULL,
    uri     TEXT    NOT NULL,
    FOREIGN KEY ( pkg_id )
        REFERENCES packages ( id )
        ON DELETE CASCADE
);

CREATE TABLE packages_tags (
    pkg_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    FOREIGN KEY ( pkg_id )
        REFERENCES packages ( id )
        ON DELETE CASCADE
);

CREATE TABLE tags (
    id              INTEGER PRIMARY KEY AUTOINCREMENT
                    NOT NULL,
    name            VARCHAR(50)
                    NOT NULL
);

CREATE TABLE licenses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT
                    NOT NULL,
    name            VARCHAR(50),
    description     TEXT,
    active          BOOLEAN DEFAULT 0
);

CREATE UNIQUE INDEX license_name ON licenses (name);