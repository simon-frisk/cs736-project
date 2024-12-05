from dataclasses import dataclass
from functools import cached_property
from typing import Iterable

from matplotlib.axes import Axes
import parsy


def _lexeme(prsr: parsy.Parser) -> parsy.Parser:
    return prsr.skip(parsy.regex(r"\s*"))


_posint = parsy.digit.at_least(1).concat().map(int)


@dataclass
class CacheStat:
    """Cache hit rate statistics"""

    hit_count: int
    miss_count: int

    @classmethod
    def parse_miss_rate(cls, inp: str) -> "CacheStat":
        hit_pct = _lexeme(parsy.regex(r"[0-9]+(\.[0-9]+)?%").desc("hit percentage"))

        lparen = _lexeme(parsy.string("("))
        hit_count = _lexeme(_posint)
        slash = _lexeme(parsy.string("/"))
        total_count = _lexeme(_posint)
        rparen = _lexeme(parsy.string(")"))
        hc, tc = parsy.seq(
            hit_pct >> lparen >> hit_count, slash >> total_count << rparen
        ).parse(inp)
        return cls(hc, tc - hc)

    @cached_property
    def total_count(self) -> int:
        return self.hit_count + self.miss_count


@dataclass
class MissRatePoint:
    """Point on a miss rate curve"""

    count: int
    size: int
    stat: CacheStat

    @classmethod
    def parse_miss_rate_point(cls, inp: str) -> "MissRatePoint":
        count = _lexeme(_posint)
        size = _lexeme(_posint)
        (ct, sz), rest = parsy.seq(count, size).parse_partial(inp)
        stat = CacheStat.parse_miss_rate(rest)
        return cls(ct, sz, stat)


@dataclass
class MissRateCurve:
    _curve: list[MissRatePoint]

    @classmethod
    def parse_miss_rate_curve(cls, lines: Iterable[str]) -> "MissRateCurve":
        """Parse a list of points into a miss rate curve"""
        return cls([MissRatePoint.parse_miss_rate_point(ln) for ln in lines])

    def plot(self, axs: Axes):
        """Plot a miss rate curve with matplotlib"""
        sizes = [pt.size for pt in self._curve]
        mrs = [pt.stat.miss_count / pt.stat.total_count for pt in self._curve]
        axs.plot(sizes, mrs)