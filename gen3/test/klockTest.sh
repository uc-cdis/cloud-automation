test_kube_lock() {
  local testuser="---a-bad-user-name---____......"
  # Setup - acquire test runner lock - running concurrent tests in the same env won't work
  if ! gen3 klock lock testrunner "$testuser" 600 -w 600; then
    because $? "Failed to acquire testrunner lock"
    return 1
  fi

  gen3 klock lock | grep -e "gen3 klock lock lock-name owner max-age [--wait wait-time]"; because $? "calling klock lock without arguments should show the help documentation"
  gen3 klock lock testlock "$testuser" not-a-number 2>&1 | grep -e "max-age is not-a-number, must be an integer"; because $? "calling klock lock without a number for max-age should show this error message"
  gen3 klock lock testlock "$testuser" 60 -w not-a-number 2>&1 | grep -e "wait-time is not-a-number, must be an integer"; because $? "calling klock lock without a number for wait-time should show this error message"
  # Do not do this - it break any klock's active in the test environment! :-(
  #g3kubectl delete configmap locks
  gen3 klock lock testlock "$testuser" 300; because $? "calling klock lock for the first time for a lock should successfully lock it, and it should create the configmap locks if it does not exist already"
  ! gen3 klock lock testlock "$testuser" 60; because $? "calling klock lock for the second time in a row for a lock should fail to lock it"
  gen3 klock lock testlock2 "$testuser" 60; because $? "klock lock should be able to handle multiple locks"
  gen3 klock lock testlock3 testuser2 60; because $? "klock lock should be able to handle multiple users"
  ! gen3 klock lock testlock testuser2 60; because $? "attempting to lock an already locked lock with a different user should fail"
  gen3 klock lock testlock4 "$testuser" 10
  sleep 11
  gen3 klock lock testlock4 "$testuser" 15; because $? "attempting to lock an expired lock should succeed"
  gen3 klock lock testlock5 "$testuser" 20; because $? "locking testlock5 should be fine"
  ! gen3 klock lock testlock5 testuser2 10 -w 2; because $? "wait for testlock5 is too short, so klock lock should fail to acquire lock"
  gen3 klock lock testlock6 "$testuser" 10
  gen3 klock lock testlock6 testuser2 10 -w 20; because $? "wait is longer than expiry time on the first user, so klock lock should succeed to acquire lock"

  # cleanup
  for lock in testlock testlock2 testlock3 testlock4 testlock5 testlock6; do
    for user in "$testuser" testuser testuser2; do
      gen3 klock unlock $lock $user
    done
  done

  gen3 klock unlock testrunner "$testuser"; because $? "should release testrunner lock"

  # Do not do this - it break any klock's active in the test environment! :-(
  #g3kubectl delete configmap locks
}

test_kube_unlock() {
  # Setup - acquire test runner lock - running concurrent tests in the same env won't work
  if ! gen3 klock lock testrunner testuser 360 -w 360; then
    because $? "Failed to acquire testrunner lock"
    return 1
  fi
  # Do not do this - it break any klock's active in the test environment! :-(
  #g3kubectl delete configmap locks

  gen3 klock unlock | grep -e "gen3 klock unlock lock-name owner"; because $? "calling klock unlock without arguments should show the help documentation"
  gen3 klock lock testlock testuser 300
  ! gen3 klock unlock unlockfail testuser; because $? "calling klock unlock for the first time on a lock that does not exist should fail"
  ! gen3 klock unlock testlock testuser2; because $? "calling klock unlock for the first time on a lock the user does not own should fail"
  gen3 klock unlock testlock testuser; because $? "calling klock unlock for the first time on a lock the user owns should succeed"
  ! gen3 klock unlock testlock testuser; because $? "calling klock unlock for the second time on a lock the user owns should fail because the lock is already unlocked"

  # teardown
  # Do not do this - it break any klock's active in the test environment! :-(
  #g3kubectl delete configmap locks
  gen3 klock unlock testrunner testuser
}

shunit_runtest "test_kube_lock" "klock"
shunit_runtest "test_kube_unlock" "klock"
