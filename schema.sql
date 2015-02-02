CREATE TABLE packages (
    id          INTEGER         PRIMARY KEY AUTOINCREMENT
                                NOT NULL,
    license     VARCHAR(50)     NOT NULL,
    name        VARCHAR(100)    NOT NULL,
    description TEXT,
    web         TEXT            NOT NULL,
    repository  VARCHAR(100),
    FOREIGN KEY ( license )
        REFERENCES licenses ( name )
);

CREATE TABLE releases (
    id      INTEGER PRIMARY KEY AUTOINCREMENT
                    NOT NULL,
    package_id  INTEGER NOT NULL,
    version TEXT    NOT NULL,
    method  TEXT    NOT NULL,
    uri     TEXT    NOT NULL,
    FOREIGN KEY ( package_id )
        REFERENCES packages ( id )
        ON DELETE CASCADE
);

CREATE TABLE packages_tags (
    package_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    FOREIGN KEY ( package_id )
        REFERENCES packages ( id )
        ON DELETE CASCADE
);

CREATE TABLE packages_users (
    package_id     INTEGER NOT NULL,
    user_id         INTEGER NOT NULL,
    kind            VARCHAR(50),
    FOREIGN KEY ( package_id )
        REFERENCES packages ( id )
        ON DELETE CASCADE
);

CREATE TABLE users (
    id              INTEGER PRIMARY KEY AUTOINCREMENT
                            NOT NULL,
    email           VARCHAR(120) NOT NULL,
    password        VARCHAR(120),
    display_name    VARCHAR(120),
    github          VARCHAR(120)
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
CREATE UNIQUE INDEX user_email ON users (email);