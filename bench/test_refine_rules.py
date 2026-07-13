import unittest
from refine_rules import refine

DICT = {"깃허브": "GitHub", "풀 리퀘스트": "PR", "풀리퀘스트": "PR"}

class TestRefine(unittest.TestCase):
    def test_dictionary_substitution(self):
        self.assertEqual(refine("깃허브에 올렸어", DICT), "GitHub에 올렸어.")

    def test_longest_key_first(self):
        # "풀 리퀘스트"(공백 포함, 더 긴 키)가 먼저 매칭되어야 함
        self.assertEqual(refine("풀 리퀘스트 보내줘", DICT), "PR 보내줘.")

    def test_whitespace_cleanup(self):
        self.assertEqual(refine("안녕  하세요 ", {}), "안녕 하세요.")

    def test_keeps_existing_terminal_punctuation(self):
        self.assertEqual(refine("배포했나요?", {}), "배포했나요?")
        self.assertEqual(refine("좋아요!", {}), "좋아요!")

    def test_empty_input(self):
        self.assertEqual(refine("", {}), "")

if __name__ == "__main__":
    unittest.main()
