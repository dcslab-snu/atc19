#!/usr/bin/env python3
# coding: UTF-8

import argparse
from pathlib import Path
from typing import Dict, List, Tuple


def main():
    parser = argparse.ArgumentParser(description='Merge multiple avg.csv that come from bench_launcher into single csv file')
    parser.add_argument('workspace', type=str, nargs='+',
                        help='The directory path where the experiment directories are located')
    parser.add_argument('dest_file', type=str, default='merged_avg.csv', nargs='?', help='merged avg file (csv format)')
    args = parser.parse_args()

    merged: List[Dict[str, float], ...] = list()

    for exp in sorted(Path(args.workspace).iterdir()):
        avg_path = exp / 'output' / 'avg.csv'

        if not (exp / 'config.json').is_file() \
                or not (exp / 'result.json').is_file() \
                or not avg_path.is_file():
            continue

        with avg_path.open() as fp:
            arr: Tuple[Dict[str, float], ...] = tuple(dict(name=name) for name in fp.readline().strip().split(',')[1:])

            for line in fp:
                splitted = line.strip().split(',')
                category = splitted[0]

                for idx, val in enumerate(splitted[1:]):
                    arr[idx][category] = float(val)

            merged += arr

    with Path(args.dest_file).open(mode='w') as wfp:
        for key in merged[0].keys():
            wfp.write(f'{key},')
            wfp.write(','.join(str(elem[key]) for elem in merged) + '\n')


if __name__ == '__main__':
    main()
