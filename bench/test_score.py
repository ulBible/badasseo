import unittest
from score import levenshtein, normalize, cer, cer_content, spacing_gap

class TestScore(unittest.TestCase):
    def test_levenshtein_known_values(self):
        self.assertEqual(levenshtein("", ""), 0)
        self.assertEqual(levenshtein("abc", "abc"), 0)
        self.assertEqual(levenshtein("abc", "axc"), 1)   # 치환
        self.assertEqual(levenshtein("abc", "ac"), 1)    # 삭제
        self.assertEqual(levenshtein("ac", "abc"), 1)    # 삽입
        self.assertEqual(levenshtein("김치", "감치"), 1)

    def test_normalize_collapses_whitespace(self):
        self.assertEqual(normalize("안녕  하세요\n"), "안녕 하세요")

    def test_cer_perfect_and_simple(self):
        self.assertEqual(cer("안녕하세요", "안녕하세요"), 0.0)
        # ref 5자, 1치환 → 0.2
        self.assertAlmostEqual(cer("안녕하세요", "안녕하세용"), 0.2)

    def test_cer_content_ignores_spacing(self):
        # 내용 동일, 띄어쓰기만 다름 → content 0
        self.assertEqual(cer_content("안녕 하세요", "안녕하세요"), 0.0)
        # 공백 포함 CER은 0보다 큼 → spacing_gap > 0
        self.assertGreater(spacing_gap("안녕 하세요", "안녕하세요"), 0.0)

    def test_spacing_gap_zero_when_content_differs_equally(self):
        # 공백 문제 없으면 gap 0
        self.assertEqual(spacing_gap("안녕하세요", "안녕하세용"), 0.0)

    def test_cer_empty_ref_guard(self):
        self.assertEqual(cer("", "아무거나"), 1.0)  # ref 공백이면 1.0 고정(0나눗셈 방지)

if __name__ == "__main__":
    unittest.main()
