import json, os, sys, unittest
from types import SimpleNamespace
sys.path.insert(0, os.path.dirname(__file__))
import dev_prs as prs

NOW = 1_800_000_000.0
RECENT = "2027-01-15T07:00:00Z"  # inside the window of NOW
OLD = "2020-01-01T00:00:00Z"


def run_with(responses):
    def run(args, **kw):
        key = " ".join(args[1:3] + ([args[3]] if args[1] == "pr" else []))
        for prefix, value in responses.items():
            if key.startswith(prefix):
                if isinstance(value, Exception):
                    return SimpleNamespace(returncode=1, stdout="", stderr=str(value))
                return SimpleNamespace(returncode=0, stdout=json.dumps(value), stderr="")
        return SimpleNamespace(returncode=1, stdout="", stderr="unexpected " + key)
    return run


class ChecksTests(unittest.TestCase):
    def test_summaries(self):
        run = lambda c, s="COMPLETED", n="x": {"__typename": "CheckRun", "name": n, "status": s, "conclusion": c}
        self.assertEqual(prs.summarize_checks([]), ("none", []))
        self.assertEqual(prs.summarize_checks([run("SUCCESS"), run("SKIPPED")]), ("passing", []))
        self.assertEqual(prs.summarize_checks([run("SUCCESS"), run("", "IN_PROGRESS")]), ("pending", []))
        self.assertEqual(prs.summarize_checks([run("SUCCESS"), run("FAILURE", n="build")]), ("failing", ["build"]))
        self.assertEqual(prs.summarize_checks([{"__typename": "StatusContext", "context": "ci/x", "state": "FAILURE"}]), ("failing", ["ci/x"]))
        self.assertEqual(prs.summarize_checks([{"__typename": "StatusContext", "context": "ci/x", "state": "PENDING"}]), ("pending", []))
        self.assertEqual(prs.summarize_checks([None, "junk"]), ("none", []))


class CollectTests(unittest.TestCase):
    def test_collects_open_prs_with_ci_and_review_and_skips_stale_ones(self):
        repo = {"name": "app", "nameWithOwner": "me/app"}
        responses = {
            "search prs": None,  # replaced below per call order
        }
        calls = []
        def run(args, **kw):
            calls.append(args)
            if args[1] == "search" and "--state=open" in args:
                out = [{"number": 1, "title": "A", "url": "u1", "repository": repo, "isDraft": False, "updatedAt": RECENT},
                       {"number": 2, "title": "Old", "url": "u2", "repository": repo, "isDraft": False, "updatedAt": OLD}]
            elif args[1] == "search":
                out = [{"number": 9, "title": "Done", "url": "u9", "repository": repo, "closedAt": RECENT}]
            else:
                out = {"statusCheckRollup": [{"__typename": "CheckRun", "name": "t", "status": "COMPLETED", "conclusion": "FAILURE"}], "reviewDecision": "CHANGES_REQUESTED", "state": "OPEN"}
            return SimpleNamespace(returncode=0, stdout=json.dumps(out), stderr="")
        result = prs.collect(run=run, now=NOW)
        self.assertEqual(len(result["prs"]), 1)
        pr = result["prs"][0]
        self.assertEqual((pr["repo"], pr["number"], pr["ci"], pr["failing"], pr["review"]), ("me/app", 1, "failing", ["t"], "CHANGES_REQUESTED"))
        self.assertEqual(result["merged"][0]["number"], 9)
        self.assertEqual(len([c for c in calls if c[1] == "pr"]), 1)

    def test_a_failing_detail_call_does_not_hide_the_pr(self):
        repo = {"name": "app", "nameWithOwner": "me/app"}
        def run(args, **kw):
            if args[1] == "pr":
                return SimpleNamespace(returncode=1, stdout="", stderr="rate limited")
            out = [{"number": 1, "title": "A", "url": "u", "repository": repo, "isDraft": True, "updatedAt": RECENT}] if "--state=open" in args else []
            return SimpleNamespace(returncode=0, stdout=json.dumps(out), stderr="")
        result = prs.collect(run=run, now=NOW)
        self.assertEqual((result["prs"][0]["ci"], result["prs"][0]["draft"]), ("none", True))

    def test_gh_errors_raise_for_the_caller_to_report(self):
        run = lambda args, **kw: SimpleNamespace(returncode=1, stdout="", stderr="not logged in")
        with self.assertRaises(RuntimeError):
            prs.collect(run=run, now=NOW)


if __name__ == "__main__":
    unittest.main()
