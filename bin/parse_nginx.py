#!/usr/bin/env python3
# -*- coding: utf-8 -*- #
#==============================================================#
# File      :   inventory_load
# Desc      :   parse nginx access to into csv format
# Ctime     :   2022-05-22
# Mtime     :   2022-05-22
# Path      :   bin/inventory_cmdb
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
import os, sys, re, csv, datetime

NGINX_ACCESS_LOG_REGEX = r'(?P<ip>.*?)- - \[(?P<time>.*?)\] "(?P<request>.*?)" (?P<status>.*?) (?P<bytes>.*?) "(?P<referer>.*?)" "(?P<ua>.*?)"'
PATTERN = re.compile(NGINX_ACCESS_LOG_REGEX)


def parse(line):
    """Parse single line nginx journal"""
    dic = {}
    try:
        result = PATTERN.match(line)
        ip, ts, req, status, bytes, referer, ua = result.group("ip").strip(), result.group("time"), result.group(
            "request"), result.group("status"), result.group("bytes"), result.group("referer"), result.group("ua")
        if ip == '-' or ip == "": return False
        ip = ip.split(",")[0].strip()
        ts = ts.replace(" +0800", "")
        ts = datetime.datetime.strptime(ts, "%d/%b/%Y:%H:%M:%S").strftime("%Y-%m-%d %H:%M:%S")

        request = result.group("request")
        url = request.split()[1].split("?")[0]
        method = request.split()[0]
        ua_short = 'other'
        if "Windows NT" in ua:
            ua_short = "win"
        elif "iPad" in ua:
            ua_short = "ipad"
        elif "Android" in ua:
            ua_short = "android"
        elif "Macintosh" in ua:
            ua_short = "mac"
        elif "iPhone" in ua:
            ua_short = "iphone"
        return [ip, ts, request, status, bytes, referer, ua]  # , method, url, ua_short]
    except:
        return False


def parse_log(path):
    result, errors = [], []
    with open(path, mode="r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            dic = parse(line)
            if dic:
                result.append(dic)
            else:
                errors.append(line)  # Dirty data added to error_lst In the list
    return result, errors


def convert_file(log_file_name, csv_file_name):
    sys.stderr.write("parsing %s to %s" % (log_file_name, csv_file_name))
    with open(log_file_name, mode="r", encoding='utf-8') as src:
        with open(csv_file_name, 'w') as dst:
            out = csv.writer(dst, delimiter=',')
            for line in src:
                row = parse(line)
                if row:
                    out.writerow(row)
                else:
                    sys.stderr.write("Error parsing line: %s" % line)


def convert_stream():
    out = csv.writer(sys.stdout, delimiter=',')
    line = None
    while 1:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            row = parse(line)
            if row:
                out.writerow(row)
            else:
                sys.stderr.write("Error parsing line: %s" % line)

        except KeyboardInterrupt as ke:
            sys.stderr.write("Interrupted at line: %s" % line)
            try:
                sys.exit(130)
            except:
                sys.exit(0)
        except (AttributeError, IndexError) as e:
            sys.stderr.write("Error parsing line: %s" % line)


def usage(progname):
    sys.stderr.write(
        f"""Usage: {progname} <access.log> <accesslog.csv> Or pipe stdout in: 'cat <file> | {progname}'""")


def main(argv, stdout, environ):
    progname = argv[0]
    if sys.stdin.isatty():
        if len(argv) == 3:
            log_file_name = sys.argv[1]
            csv_file_name = sys.argv[2]
            convert_file(log_file_name, csv_file_name)
        else:
            usage(progname)
            sys.exit(0)
    else:
        convert_stream()


if __name__ == "__main__":
    main(sys.argv, sys.stdout, os.environ)
