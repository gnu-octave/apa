function test_apa ()
% Self-test for @mpfr_t class and MPFR-low-level interface.

  % Check if @mpfr_t variables exist
  if (mpfr_t.get_data_size ())
    error ('apa:test:dirtyEnvironment', ...
      ['Existing @mpfr_t variables detected.  Please run the test suite ', ...
       'in a clean Octave/Matlab session.\n\nRun:\n  clear all; test_apa']);
  end

  % Good input
  % The value `intmax ("int32") - 256` is taken from "mpfr.h" and should work
  % for 32- and 64-bit precision types.
  for i = [4, intmax("int32") - 256 - 1, 53]
    mpfr_set_default_prec (i);
    assert (mpfr_get_default_prec () == i);
  end
  % Bad input
  mpfr_set_default_prec (42)
  mpfr_t.set_verbose (0);
  for i = {0, inf, -42, -2, 1/6, nan, 'c', eye(3), intmax('int64')}
    try
      mpfr_set_default_prec (i{1});
      error ('apa:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'apa:mexFunction'));
    end
  end
  mpfr_t.set_verbose (1);

  % Good input
  for i = -1:3
    mpfr_set_default_rounding_mode (i);
    assert (mpfr_get_default_rounding_mode () == i);
  end
  % Bad input
  mpfr_set_default_rounding_mode (0);
  mpfr_t.set_verbose (0);
  for i = {inf, -42, -2, 4, 1/6, nan, 'c', eye(3)}
    try
      mpfr_set_default_rounding_mode (i{1});
      error ('apa:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'apa:mexFunction'));
    end
  end
  mpfr_t.set_verbose (1);

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
  % Bad input non-MPFR function "mpfr_t.allocate"
  mpfr_t.set_verbose (0);
  for i = {1/2, inf, -42, -1, -2, nan, 'c', eye(3)}
    try
      mpfr_t.allocate (i{1});
      error ('apa:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'apa:mexFunction'));
      assert (mpfr_t.get_data_size () == N^2 + 1);
      assert (mpfr_t.get_data_capacity () == 2 * DATA_CHUNK_SIZE);
    end
  end
  mpfr_t.set_verbose (1);

  % Good input
  mpfr_set_default_prec (53);
  vals = {inf, nan, pi, 1/6, 42, 2, 1, 2.5, eye(4), [1, 2; nan, 4]};
  vals = [vals, cellfun(@uminus, vals, "UniformOutput", false)];
  for i = vals
    assert (isequaln (double (mpfr_t (i{1})), i{1}));
  end
  % Bad input (precision)
  mpfr_t.set_verbose (0);
  for i = {inf, -42, -2, 1/6, nan, 'c', eye(3), intmax('int64')}
    try
      mpfr_t (1, i{1});
      error ('apa:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'apa:mexFunction'));
    end
  end
  mpfr_t.set_verbose (1);
  % Bad input (rounding mode)
  mpfr_t.set_verbose (0);
  for i = {inf, -42, -2, 4, 1/6, nan, 'c', eye(3)}
    try
      mpfr_t (1, 53, i{1});
      error ('apa:test:missed', 'Should never be reached');
    catch e
      assert (strcmp (e.identifier, 'apa:mexFunction'));
    end
  end
  mpfr_t.set_verbose (1);


  % ===================
  % Indexing operations
  % ===================

  N = 4;
  A = rand (N);
  Ampfr = mpfr_t (A);

  % 1D indexing
  for i = 1:numel (A)
    assert (isequal (double (Ampfr(i)), A(i)));
  end
  assert (isequal (double (Ampfr(:)), A(:)));

  % 2D indexing
  for i = 1:N
    for j = 1:N
      assert (isequal (double (Ampfr(i,j)), A(i,j)));
      assert (isequal (double (Ampfr(1:i,j)), A(1:i,j)));
      assert (isequal (double (Ampfr(i,1:j)), A(i,1:j)));
      assert (isequal (double (Ampfr(1:i,1:j)), A(1:i,1:j)));
      assert (isequal (double (Ampfr(i:end,j)), A(i:end,j)));
      assert (isequal (double (Ampfr(i,j:end)), A(i,j:end)));
      assert (isequal (double (Ampfr(i:end,j:end)), A(i:end,j:end)));
      assert (isequal (double (Ampfr(i:j,i:j)), A(i:j,i:j)));
      assert (isequal (double (Ampfr(j:i,j:i)), A(j:i,j:i)));
    end
    assert (isequal (double (Ampfr(i,:)), A(i,:)));
    assert (isequal (double (Ampfr(i,[])), A(i,[])));
  end
  for j = 1:N
    assert (isequal (double (Ampfr(:,j)), A(:,j)));
    assert (isequal (double (Ampfr([],j)), A([],j)));
  end
  assert (isequal (double (Ampfr([],:)), A([],:)));
  assert (isequal (double (Ampfr(:,[])), A(:,[])));


  % =====================
  % Arithmetic operations
  % =====================

  for ops = {@uminus}
    op = ops{1};
    assert (isequal (double (op (mpfr_t (1))),   op (1)));
    assert (isequal (double (op (mpfr_t (1:3))), op (1:3)));
  end

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

  for ops = {@power}
    op = ops{1};
    assert (isequal (double (op (mpfr_t (1:3), mpfr_t (1:3))), op ((1:3), (1:3))));
    assert (isequal (double (op (mpfr_t (1:3), mpfr_t (1)  )), op ((1:3), 1)));
    assert (isequal (double (op (mpfr_t (1)  , mpfr_t (1:3))), op (1, (1:3))));

    assert (isequal (double (op (mpfr_t (1:3), (1:3))), op ((1:3), (1:3))));
    assert (isequal (double (op (mpfr_t (1:3), 1)),     op ((1:3), 1)));
  end


  % ====================
  % Comparison functions
  % ====================

  for ops = {@lt, @gt, @le, @ge, @ne, @eq}
    op = ops{1};
    assert (isequal (double (op (mpfr_t (1:3), mpfr_t (1:3))), op ((1:3), (1:3))));
    assert (isequal (double (op (mpfr_t (1:3), (1:3))), op ((1:3), (1:3))));
    assert (isequal (double (op ((1:3), mpfr_t (1:3))), op ((1:3), (1:3))));
  end

end
