#!/usr/bin/env python3
# -*- coding: utf-8 -*- #
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)

__author__ = 'Vonng (rh@vonng.com)'

# A Wrapper for psycopg2

import psycopg2
import psycopg2.extras
from psycopg2.extras import Json

DEFAULT_BUF_SIZE = 2000


# PSQL is a convenient wrapper for psycopg2
# Usage:
# from psql import *
# pg = PSQL('service=meta')
# c.list()
# c.execute('SELECT 1')


class PSQL(object):
    def __init__(self, url=''):
        self.url = url
        self.conn = psycopg2.connect(url)

    def reconnect(self):
        self.conn = psycopg2.connect(self.url)

    def execute(self, sql, data=None):
        with self.conn.cursor() as cursor:
            try:
                cursor.execute(sql, vars=data)
                self.conn.commit()
                return cursor.rowcount
            except Exception:
                self.conn.rollback()
                raise

    def execute_many(self, sql, data):
        with self.conn.cursor() as cursor:
            try:
                cursor.executemany(sql, vars_list=data)
                self.conn.commit()
                return cursor.rowcount
            except:
                self.conn.rollback()
                raise

    def execute_mono(self, sql, data_seq, skip_error=True):
        '''
        Execute sql for each record one by one.
        '''
        total_num = 0
        affect_num = 0
        with self.conn.cursor() as cursor:
            for record in data_seq:
                total_num += 1
                try:
                    cursor.execute(sql, record)
                    self.conn.commit()
                    affect_num += 1
                except:
                    self.conn.rollback()
                    if not skip_error:
                        raise


                        # rollback and skip
        return total_num, affect_num

    def iexecute(self, sql, idata=None, buffer=True, buf_sz=DEFAULT_BUF_SIZE, skip_error=False):
        if not buffer:
            return self.execute_mono(sql, idata, skip_error)
        buf = []
        total_num = 0
        affect_num = 0
        for record in idata:
            buf.append(record)
            total_num += 1
            if total_num % buf_sz == 0:
                try:
                    affect_num += self.execute_many(sql, buf)
                except:
                    if not skip_error: raise
                finally:
                    buf = []
        else:
            # commit remain data
            if len(buf) > 0:
                try:
                    affect_num += self.execute_many(sql, buf)
                except:
                    if not skip_error: raise
        return total_num, affect_num

    def fetch(self, sql, data=None):
        with self.conn.cursor() as cursor:
            cursor.execute(sql, vars=data)
            return cursor.fetchall()

    def fetch_one(self, sql, data=None):
        with self.conn.cursor() as cursor:
            cursor.execute(sql)
            return cursor.fetchone()

    def fetch_scale(self, sql, data=None):
        with self.conn.cursor() as cursor:
            cursor.execute(sql, data)
            res = cursor.fetchone()
            return res[0] if res and len(res) > 0 else None

    def fetch_column(self, sql, data=None):
        with self.conn.cursor() as cursor:
            cursor.execute(sql)
            return [item[0] for item in cursor.fetchall()]

    def ifetch(self, sql, name=None, buf_size=DEFAULT_BUF_SIZE):
        '''
        Suit for large bulk selection. Use fetchmany & ServerSide cursor
        '''
        # if name is None:
        #     name = "ifetch_%s" % (int(time.time()))
        with self.conn.cursor(name=name) as cursor:
            cursor.arraysize = buf_size
            cursor.execute(sql)
            while True:
                buf = cursor.fetchmany()
                n_records = len(buf)
                if n_records == 0:
                    return
                for record in buf:
                    yield record

    def call(self, func, args):
        with self.conn.cursor() as cursor:
            cursor.callproc(func, args)
            return cursor.fetchall()

    def count(self, table, condition=None):
        if condition and condition != '':
            sql = "SELECT count(*) FROM {0} WHERE {1};".format(table, condition)
        else:
            sql = "SELECT count(*) FROM {0};".format(table)
        return self.fetch_scale(sql)

    def glimpse(self, table, limit=None):
        '''
        Inspect a table by sampling some data
        '''
        if limit and int(limit) > 0:
            sql = "SELECT * FROM {0} LIMIT {1};".format(table, limit)
        else:
            sql = "SELECT * FROM {0};".format(table)

        return self.fetch(sql)

    def desc(self, table, schema='public'):
        sql = "SELECT ordinal_position,column_name,data_type FROM information_schema.columns " \
              "WHERE table_schema= '{0}' and table_name = '{1}' ORDER BY ordinal_position;".format(
            schema, table
        )
        return self.fetch(sql)

    def drop(self, table):
        '''
        Drop a specfic table by name
        '''
        sql = "DROP TABLE IF EXISTS {0};".format(table)
        self.execute(sql)

    def truncate(self, table):
        '''
        Delete a specific table by table name
        '''
        sql = "DELETE FROM {0};".format(table)
        self.execute(sql)

    def rename(self, table, new_name):
        '''
        Delete a specific table by table name
        '''
        sql = "ALTER TABLE {0} RENAME TO {1};".format(table, new_name)
        self.execute(sql)

    def list(self, schema='public'):
        sql = "SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = '{0}'".format(schema)
        return self.fetch_column(sql)

    def insert(self, table, columns, value):
        '''
        Insert single record
        '''
        col_spec = ','.join(columns)
        val_spec = ','.join(['%s'] * len(columns))
        sql = self.insert_sql(table, columns)
        return self.execute(sql, value)

    def insert_json(self, table, json_data):
        '''
        Insert single json record. Only for convenient use.
        '''
        columns = []
        values = []
        for column, value in json_data.iteritems():
            columns.append(column)
            values.append(value)
        sql = self.insert_sql(table, columns)
        return self.execute(sql, values)

    @staticmethod
    def insert_sql(table, columns, do_nothing=False):
        col_spec = ','.join(columns)
        val_spec = ','.join(['%s'] * len(columns))
        sql = 'INSERT INTO {0} ({1}) VALUES ({2})'.format(table, col_spec, val_spec)
        if do_nothing:
            sql = 'INSERT INTO {0} ({1}) VALUES ({2}) ON CONFLICT DO NOTHING;'.format(table, col_spec, val_spec)
        return sql
