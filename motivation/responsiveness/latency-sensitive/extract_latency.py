#!/usr/bin/env python3
# coding: UTF-8

import argparse
import math
import sys
from itertools import chain
from typing import Iterable, List

MIN_PYTHON = (3, 6)


def _parse_tsv(file_path: str) -> Iterable[int]:
    with open(file_path) as fp:
        head_arr = fp.readline().split('\t')
        ttime_idx = head_arr.index('ttime')

        for line in fp:
            yield int(line.split('\t')[ttime_idx])


def _store_csv_result(latencies: List[int], dest: str) -> None:
    size = len(latencies)

    with open(dest, 'w') as fp:
        fp.write('Percentage served,Time in ms\n')

        for per in chain(range(100), (99.5, 99.9, 99.99, 99.999)):
            idx = math.ceil((size - 1) * per / 100)

            fp.write(f'{per},{latencies[idx]}\n')

        fp.write(f'100,{latencies[-1]}\n')


def main():
    parser = argparse.ArgumentParser(description='Extract tail latency from multiple tsv output that comes from ab.')
    parser.add_argument('tsv_files', metavar='ab_tsv', type=str, nargs='+',
                        help='tsv format file comes from ab with -g option')
    parser.add_argument('dest', type=str, help='Path of result csv file')
    args = parser.parse_args()

    _store_csv_result(sorted(chain(*map(_parse_tsv, args.tsv_files))), args.dest)


if __name__ == '__main__':
    if sys.version_info < MIN_PYTHON:
        sys.exit('Python {}.{} or later is required.\n'.format(*MIN_PYTHON))

    main()
