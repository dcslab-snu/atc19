#!/usr/bin/env python3
# coding: UTF-8

import argparse
import glob
import sys
from collections import defaultdict
from itertools import chain
from pathlib import Path
from typing import Dict, Iterable, List

MIN_PYTHON = (3, 6)


def parse_perf(log_path: Path) -> None:
    data_map: Dict[str, List[int]] = defaultdict(list)

    with log_path.open() as fp:
        for line in fp:
            splitted = line.split(',')

            event_name = splitted[3]
            try:
                event_value = int(splitted[1])
            except ValueError:
                event_value = None
            data_map[event_name].append(event_value)

    with log_path.with_suffix('.csv').open('w') as fp:
        fp.write(','.join(data_map.keys()))
        fp.write('\n')
        for values in zip(*data_map.values()):
            fp.write(','.join(map(str, values)))
            fp.write('\n')


def main() -> None:
    if sys.version_info < MIN_PYTHON:
        sys.exit('Python {}.{} or later is required.\n'.format(*MIN_PYTHON))

    parser = argparse.ArgumentParser(description='Parse perf output to csv format')
    parser.add_argument('perf_log', metavar='PERF_LOG', type=str, nargs='+', help='Perf log file paths')

    args = parser.parse_args()

    perf_logs: Iterable[str] = chain(*(glob.glob(path) for path in args.perf_log))

    for perf_log in perf_logs:
        parse_perf(Path(perf_log))


if __name__ == '__main__':
    main()
