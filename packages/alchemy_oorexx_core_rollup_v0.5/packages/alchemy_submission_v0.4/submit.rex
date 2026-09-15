/* Canonical producer-side submission CLI. Paths should not contain spaces. */
parse arg line
repo=""; package=""; submittedBy=""; submissionId=""; dryRun=.false; jsonOut=.false
do i=1 to words(line)
  token=word(line,i)
  select
    when token~left(7)="--repo=" then repo=token~substr(8)
    when token~left(10)="--package=" then package=token~substr(11)
    when token~left(15)="--submitted-by=" then submittedBy=token~substr(16)
    when token~left(16)="--submission-id=" then submissionId=token~substr(17)
    when token="--dry-run" then dryRun=.true
    when token="--json" then jsonOut=.true
    otherwise do
      say "ERROR unknown argument:" token
      exit 2
    end
  end
end
if repo="" | package="" | submittedBy="" then do
  say "usage: rexx submit.rex --repo=PATH --package=PATH --submitted-by=NAME [--submission-id=ID] [--dry-run] [--json]"
  exit 2
end
send=.AlchemyGitSubmissionSender~new~submit(repo,package,submittedBy,submissionId,dryRun)
if jsonOut then do
  out=.directory~new
  out["schema"]="alchemy.submission.cli/0.1"
  out["submission_id"]=send~submissionId
  out["branch"]=send~branch
  out["body_commit"]=send~bodyCommit
  out["ready_commit"]=send~readyCommit
  out["package"]=send~packageId~key
  out["dry_run"]=send~dryRun
  say .JSON~toJSON(out)
end
else do
  say "SUBMISSION_ID=" || send~submissionId
  say "BRANCH=" || send~branch
  if send~dryRun then say "DRY_RUN=1"
  else do
    say "BODY_COMMIT=" || send~bodyCommit
    say "READY_COMMIT=" || send~readyCommit
    say "PASS SUBMISSION_PUSHED"
  end
end
exit 0
::requires "AlchemySubmission.cls"
::requires "json.cls"
