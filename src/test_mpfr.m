function test_mpfr ()
% Self-test for @mpfr_t class and mpfr_ low-level interface.

  clear -f mpfr_interface
  clear -c
  if (exist('OCTAVE_VERSION', 'builtin') == 5)
    mex --std=c99 -Wall -Wextra mpfr_interface.c -lmpfr -lgmp
  else
    mex CFLAGS='$CFLAGS --std=c99 -Wall -Wextra' mpfr_interface.c -lmpfr -lgmp
  end

  % Good input
  for i = [4, flintmax('double'), 53]
    mpfr_t.set_default_prec (i);
    assert (mpfr_t.get_default_prec () == i);
  end
  % Bad input
  mpfr_t.set_default_prec (42)
  mpfr_ ('set_verbose', 0);
  for i = {inf, -42, -2, 1/6, nan, 'c', eye(3), intmax('int64')}
    try
      mpfr_t.set_default_prec (i{1});
      error ('mp:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'mp:mexFunction'));
    end
  end
  mpfr_ ('set_verbose', 1);

  % Good input
  for i = -1:3
    mpfr_t.set_default_rounding_mode (i);
    assert (mpfr_t.get_default_rounding_mode () == i);
  end
  % Bad input
  mpfr_t.set_default_rounding_mode (0);
  mpfr_ ('set_verbose', 0);
  for i = {inf, -42, -2, 4, 1/6, nan, 'c', eye(3)}
    try
      mpfr_t.set_default_rounding_mode (i{1});
      error ('mp:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'mp:mexFunction'));
    end
  end
  mpfr_ ('set_verbose', 1);

  % Good input
  DATA_CHUNK_SIZE = 1000;
  N = ceil (sqrt (DATA_CHUNK_SIZE));
  obj = mpfr_t (1);
  assert (isequal (obj.idx, [1, 1]));
  assert (mpfr_t.get_data_size () == 1);
  assert (mpfr_t.get_data_capacity () == DATA_CHUNK_SIZE);
  obj = mpfr_t (eye (N));
  assert (isequal (obj.idx, [2, N^2 + 1]));
  assert (mpfr_t.get_data_size () == N^2 + 1);
  assert (mpfr_t.get_data_capacity () == 2 * DATA_CHUNK_SIZE);
  % Bad input non-MPFR function "allocate"
  mpfr_ ('set_verbose', 0);
  for i = {1/2, inf, -42, -1, -2, nan, 'c', eye(3)}
    try
      mpfr_ ('allocate', i{1});
      error ('mp:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'mp:mexFunction'));
      assert (mpfr_t.get_data_size () == N^2 + 1);
      assert (mpfr_t.get_data_capacity () == 2 * DATA_CHUNK_SIZE);
    end
  end
  mpfr_ ('set_verbose', 1);

  % Good input
  mpfr_t.set_default_prec (53);
  vals = {inf, nan, pi, 1/6, 42, 2, 1, 2.5, eye(4), [1, 2; nan, 4]};
  vals = [vals, cellfun(@uminus, vals, "UniformOutput", false)];
  for i = vals
    assert (isequaln (double (mpfr_t (i{1})), i{1}));
  end
  % Bad input (precision)
  mpfr_ ('set_verbose', 0);
  for i = {inf, -42, -2, 1/6, nan, 'c', eye(3), intmax('int64')}
    try
      mpfr_t (1, i{1});
      error ('mp:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'mp:mexFunction'));
    end
  end
  mpfr_ ('set_verbose', 1);
  % Bad input (rounding mode)
  mpfr_ ('set_verbose', 0);
  for i = {inf, -42, -2, 4, 1/6, nan, 'c', eye(3)}
    try
      mpfr_t (1, 53, i{1});
      error ('mp:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'mp:mexFunction'));
    end
  end
  mpfr_ ('set_verbose', 1);

  % Arithmetic operations
  % =====================

  for ops = {@plus, @minus, @times, @ldivide, @rdivide}
    op = ops{1};
    assert (isequal (double (op (mpfr_t (1:3), mpfr_t (1:3))), op ((1:3), (1:3))));
    assert (isequal (double (op (mpfr_t (1:3), mpfr_t (1)  )), op ((1:3), 1)));
    assert (isequal (double (op (mpfr_t (1)  , mpfr_t (1:3))), op (1, (1:3))));

    assert (isequal (double (op (mpfr_t (1:3), (1:3))), op ((1:3), (1:3))));
    assert (isequal (double (op ((1:3), mpfr_t (1:3))), op ((1:3), (1:3))));
    assert (isequal (double (op (mpfr_t (1:3), 1)), op ((1:3), 1)));
    assert (isequal (double (op (1, mpfr_t (1:3))), op (1, (1:3))));
  end

end
