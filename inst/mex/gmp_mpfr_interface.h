#ifndef GMP_MPFR_INTERFACE_H_
#define GMP_MPFR_INTERFACE_H_


#include <math.h>
#include <stdint.h>
#include <string.h>

#include "mex.h"
#include "mpfr.h"


#define DATA_CHUNK_SIZE 1000  // Allocate space for MPFR variables in chunks.


// State deciding about the output verbosity level
// - level = 0: no output at all (including no error messages)
// - level = 1: show error messages
// - level = 2: show error messages and precision warnings [default]
// - level = 3: very verbose debug output.
static int VERBOSE = 2;


// Macro to print a message to stdout and set mexFunction error state variable.
// IMPORTANT: Only call within mexFunction!!
#define MEX_FCN_ERR(fmt, ...) \
        do { if (VERBOSE > 0) \
               mexPrintf ("%s:%d:%s():" fmt, __FILE__, __LINE__, \
                          __func__, __VA_ARGS__); throw_error = 1; \
           } while (0)

// Macro to print very verbose debug output.  Can be called from everywhere.
#define DBG_PRINTF(fmt, ...) \
        do { if (VERBOSE > 2) \
               mexPrintf ("DBG %s:%d:%s():" fmt, __FILE__, __LINE__, \
                          __func__, __VA_ARGS__); \
           } while (0)


/**
 * Check number or input arguments.
 *
 * @param num Desired number of MEX `nrhs`.
 */

#define MEX_NARGINCHK(num) \
        if (nrhs != (num)) \
          { \
            MEX_FCN_ERR ("cmd[%d]: Invalid number of arguments.\n", cmd_code); \
            break; \
          }


/**
 * Safely declare and read MPFR_T variable(-arrays) from MEX interface.
 *
 * @param mex_rhs Position (0-based) in MEX input.
 * @param name    Desired variable name.
 */

#define MEX_MPFR_T(mex_rhs, name) \
        idx_t name; \
        if (! extract_idx ((mex_rhs), nrhs, prhs, &name)) \
          { \
            MEX_FCN_ERR ("cmd[%d]:"#name" Invalid MPFR variable indices.\n", \
                         cmd_code); \
            break; \
          }


/**
 * Safely declare and read MPFR_RND_T variable from MEX interface.
 *
 * @param mex_rhs Position (0-based) in MEX input.
 * @param name    Desired variable name.
 */

#define MEX_MPFR_RND_T(mex_rhs, name) \
        mpfr_rnd_t name = mpfr_get_default_rounding_mode (); \
        if (! extract_rounding_mode ((mex_rhs), nrhs, prhs, &name)) \
          { \
            MEX_FCN_ERR ("cmd[%d]:"#name" Rounding must be a numeric scalar " \
                         "between -1 and 3.\n", cmd_code); \
            break; \
          }


/**
 * Safely declare and read MPFR_PREC_T variable from MEX interface.
 *
 * @param mex_rhs Position (0-based) in MEX input.
 * @param name    Desired variable name.
 */

#define MEX_MPFR_PREC_T(mex_rhs, name) \
        mpfr_prec_t name = mpfr_get_default_prec (); \
        if (! extract_prec ((mex_rhs), nrhs, prhs, &name)) \
          { \
            MEX_FCN_ERR ("cmd[%d]:"#name" Precision must be a numeric " \
                         "scalar between %ld and %ld.\n", cmd_code, \
                         MPFR_PREC_MIN, MPFR_PREC_MAX); \
            break; \
          }


/**
 * Safely declare and read MPFR_EXP_T variable from MEX interface.
 *
 * @param mex_rhs Position (0-based) in MEX input.
 * @param name    Desired variable name.
 */

#define MEX_MPFR_EXP_T(mex_rhs, name) \
        mpfr_exp_t name = mpfr_get_emin (); \
        { \
        int64_t si = 0; \
        if (! extract_si ((mex_rhs), nrhs, prhs, &si)) \
          { \
            MEX_FCN_ERR ("cmd[%d]:"#name" Exponent must be a numeric " \
                         "scalar between %ld and %ld.\n", cmd_code, \
                         mpfr_get_emin (), mpfr_get_emax ()); \
            break; \
          } \
        name = (mpfr_exp_t) si; \
        }


// Data type to handle index ranges.

typedef struct
{
  size_t start;
  size_t end;
} idx_t;


// MPFR memory management
// ======================
//
// Similar to C++ std::vector:
// - xxx_capacity: number of elements that `xxx` has currently allocated
//                 space for.
// - xxx_size:     number of elements in `xxx`.

static mpfr_ptr data = NULL;
static size_t data_capacity = 0;
static size_t data_size = 0;

static idx_t* free_list = NULL;
static size_t free_list_capacity = 0;
static size_t free_list_size = 0;


/**
 * Check for valid index range.
 *
 * @param[in] idx Pointer to index (1-based, idx_t) of MPFR variables.
 *
 * @returns `0` if `idx` is invalid, otherwise `idx` is valid.
 */

int
is_valid (idx_t *idx)
{
  return ((1 <= (*idx).start) && ((*idx).start <= (*idx).end)
          && ((*idx).end <= data_size));
}


/**
 * Get length of index range.
 *
 * @param[in] idx Pointer to index (1-based, idx_t) of MPFR variables.
 *
 * @returns `0` if `idx` is invalid, otherwise `idx` is valid.
 */

inline size_t
length (idx_t *idx)
{
  return (idx->end - idx->start + 1);
}


/**
 * Function called at exit of the mex file to tidy up all memory.
 * After calling this function the initial state is restored.
 */

static void
mpfr_tidy_up (void)
{
  DBG_PRINTF ("%s\n", "Call");
  for (size_t i = 0; i < data_size; i++)
    mpfr_clear (&data[i]);
  mxFree (data);
  data = NULL;
  data_capacity = 0;
  data_size = 0;
  mxFree (free_list);
  free_list = NULL;
  free_list_capacity = 0;
  free_list_size = 0;
}


/**
 * Remove the i-th entry from the pool of free MPFR variables.
 *
 * @param i index (0-based) to entry to remove from the pool.
 */

void
free_list_remove (size_t i)
{
  for (; i < free_list_size; i++)
    {
      free_list[i].start = free_list[i + 1].start;
      free_list[i].end   = free_list[i + 1].end;
    }
  free_list_size--;
}


/**
 * Try to compress the pool of free MPFR variables.
 */

void
free_list_compress ()
{
  int have_merge = 0;
  do
    {
      have_merge = 0;
      for (size_t i = 0; i < free_list_size; i++)
        {
          // Rule 1: If end index of entry matches `data_size` decrease.
          if (free_list[i].end == data_size)
            {
              have_merge = 1;
              DBG_PRINTF ("mmgr: Rule 1 for [%d:%d].\n",
                          free_list[i].start, free_list[i].end);
              data_size = free_list[i].start - 1;
              free_list_remove (i);
              break;
            }
          // Rule 2: Merge neighboring entries.
          int do_break = 0;
          for (size_t j = i + 1; j < free_list_size; j++)
            {
              if ((free_list[i].end + 1 == free_list[j].start)
                  || (free_list[j].end + 1 == free_list[i].start))
                {
                  have_merge = 1;
                  do_break = 1;
                  DBG_PRINTF ("mmgr: Rule 2 for [%d:%d] + [%d:%d].\n",
                              free_list[i].start, free_list[i].end,
                              free_list[j].start, free_list[j].end);
                  free_list[i].start = (free_list[i].start <= free_list[j].start
                                       ? free_list[i].start
                                       : free_list[j].start);
                  free_list[i].end = (free_list[i].end >= free_list[j].end
                                     ? free_list[i].end
                                     : free_list[j].end);
                  free_list_remove (j);
                  break;
                }
            }
          if (do_break)
            break;
        }
    }
  while (have_merge);
  /* Very verbose debug output.
  for (size_t i = 0; i < free_list_size; i++)
    DBG_PRINTF ("mmgr: free_list[%d] = [%d:%d].\n", i,
                free_list[i].start, free_list[i].end);
  */
}


/**
 * Mark MPFR variable as no longer used.
 *
 * @param[in] idx Pointer to index (1-based, idx_t) of MPFR variable to be no
 *                longer used.
 *
 * @returns success of MPFR variables creation.
 */

void
mex_mpfr_mark_free (idx_t *idx)
{
  // Check for impossible start and end index.
  if (! is_valid (idx))
    {
      DBG_PRINTF ("%s\n", "Bad indices");
      return;
    }

  // Extend space if necessary.
  if (free_list_size == free_list_capacity)
    {
      size_t new_capacity = free_list_capacity + DATA_CHUNK_SIZE;
      DBG_PRINTF ("Increase capacity to '%d'.\n", new_capacity);
      if (free_list == NULL)
        {
          free_list = (idx_t*) mxMalloc (new_capacity * sizeof (idx_t));
          mexAtExit (mpfr_tidy_up);
        }
      else
        free_list = (idx_t*) mxRealloc (free_list,
                                        new_capacity * sizeof (idx_t));
      if (free_list == NULL)
        return;  // Memory allocation failed.
      mexMakeMemoryPersistent (free_list);
      free_list_capacity = new_capacity;
    }

  // Reinitialize MPFR variables (free significant memory).
  for (size_t i = idx->start - 1; i < idx->end; i++)
    {
      mpfr_clear (data + i);
      mpfr_init  (data + i);
    }

  // Append reinitialized variables to pool.
  free_list[free_list_size].start = idx->start;
  free_list[free_list_size].end   = idx->end;
  free_list_size++;

  free_list_compress ();
}


/**
 * Constructor for new MPFR variables.
 *
 * @param[in] count Number of MPFR variables to create.
 * @param[out] idx If function returns `1`, pointer to index (1-based, idx_t)
 *                 of MPFR variables, otherwise the value of `idx` remains
 *                 unchanged.
 *
 * @returns success of MPFR variable creation.
 */

int
mex_mpfr_allocate (size_t count, idx_t *idx)
{
  // Check for trivial case, failure as indices do not make sense.
  if (count == 0)
    return 0;

  // Try to reuse a free marked variable from the pool.
  for (size_t i = 0; i < free_list_size; i++)
    {
      if (count <= length (free_list + i))
        {
          idx->start = free_list[i].start;
          idx->end   = free_list[i].start + count - 1;
          DBG_PRINTF ("New MPFR variable [%d:%d] reused.\n",
                      idx->start, idx->end);
          if (count < length (free_list + i))
            free_list[i].start += count;
          else
            free_list_remove (i);
          return is_valid (idx);
        }
    }

  // Check if there is enough space to create new MPFR variables.
  if ((data_size + count) > data_capacity)
    {
      // Determine new capacity.
      size_t new_capacity = data_capacity;
      while ((data_size + count) > new_capacity)
        new_capacity += DATA_CHUNK_SIZE;

      DBG_PRINTF ("Increase capacity to '%d'.\n", new_capacity);
      // Reallocate memory.
      if (data == NULL)
        {
          data = (mpfr_ptr) mxMalloc (new_capacity * sizeof (mpfr_t));
          mexAtExit (mpfr_tidy_up);
        }
      else
        data = (mpfr_ptr) mxRealloc (data, new_capacity * sizeof (mpfr_t));
      if (data == NULL)
        return 0;  // Memory allocation failed.
      mexMakeMemoryPersistent (data);

      // Initialize new MPFR variables.
      for (size_t i = data_capacity; i < new_capacity; i++)
        mpfr_init (data + i);

      data_capacity = new_capacity;
    }

  idx->start = data_size + 1;
  data_size += count;
  idx->end   = data_size;
  DBG_PRINTF ("New MPFR variable [%d:%d] allocated.\n", idx->start, idx->end);
  return is_valid (idx);
}


/**
 * Safely read numeric double scalar from MEX input.
 *
 * @param[in] idx MEX input position index (0 is first).
 * @param[in] nrhs Number of right-hand sides.
 * @param[in] mxArray  MEX input array.
 * @param[out] prec If function returns `1`, `prec` contains the MPFR precision
 *                  extracted from the MEX input, otherwise `prec` remains
 *                  unchanged.
 *
 * @returns success of extraction.
 */

int
extract_d (int idx, int nrhs, const mxArray *prhs[], double *d)
{
  if ((nrhs > idx) && mxIsScalar (prhs[idx]) && mxIsNumeric (prhs[idx]))
    {
      *d = (double) mxGetScalar (prhs[idx]);
      return 1;
    }
  DBG_PRINTF ("%s\n", "Failed.");
  return 0;
}


/**
 * Safely read scalar signed integer (si) from MEX input.
 *
 * @param[in] idx MEX input position index (0 is first).
 * @param[in] nrhs Number of right-hand sides.
 * @param[in] mxArray  MEX input array.
 * @param[out] si If function returns `1`, `si` contains the scalar signed
 *                integer extracted from the MEX input, otherwise `si` remains
 *                unchanged.
 *
 * @returns success of extraction.
 */

int
extract_si (int idx, int nrhs, const mxArray *prhs[], int64_t *si)
{
  double d = 0.0;
  if (extract_d (idx, nrhs, prhs, &d) && mxIsFinite (d) && (floor (d) == d))
    {
      *si = (int64_t) d;
      return 1;
    }
  DBG_PRINTF ("%s\n", "Failed.");
  return 0;
}


/**
 * Safely read scalar unsigned integer (ui) from MEX input.
 *
 * @param[in] idx MEX input position index (0 is first).
 * @param[in] nrhs Number of right-hand sides.
 * @param[in] mxArray  MEX input array.
 * @param[out] ui If function returns `1`, `ui` contains the scalar unsigned
 *                integer extracted from the MEX input, otherwise `ui` remains
 *                unchanged.
 *
 * @returns success of extraction.
 */

int
extract_ui (int idx, int nrhs, const mxArray *prhs[], uint64_t *ui)
{
  int64_t si = 0.0;
  if (extract_si (idx, nrhs, prhs, &si) && (si >= 0))
    {
      *ui = (uint64_t) si;
      return 1;
    }
  DBG_PRINTF ("%s\n", "Failed.");
  return 0;
}


/**
 * Safely read vector of unsigned integer (ui) from MEX input.
 *
 * @param[in] idx MEX input position index (0 is first).
 * @param[in] nrhs Number of right-hand sides.
 * @param[in] mxArray  MEX input array.
 * @param[in] len Expected vector length.
 * @param[out] ui If function returns `1`, `ui` contains a vector of unsigned
 *                integers of length `len` extracted from the MEX input,
 *                otherwise `ui` is NULL.
 *
 * @returns success of extraction.
 */

int
extract_ui_vector (int idx, int nrhs, const mxArray *prhs[], uint64_t **ui,
                   size_t len)
{
  if ((nrhs > idx) && mxIsNumeric (prhs[idx])
      && ((mxGetM (prhs[idx]) * mxGetN (prhs[idx]) >= len)))
    {
      double* vec = mxGetPr(prhs[idx]);
      *ui = (uint64_t*) mxMalloc (len * sizeof (uint64_t));
      int good = 1;
      for (size_t i = 0; i < len; i++)
        {
          if ((vec[i] >= 0.0) && mxIsFinite (vec[i])
              && (floor (vec[i]) == vec[i]))
            (*ui)[i] = (uint64_t) vec[i];
          else
            {
              good = 0;
              break;
            }
        }
      if (good)
        return 1;
      mxFree (*ui);  // In case of an error free space.
      *ui = NULL;
    }
  DBG_PRINTF ("%s\n", "Failed.");
  return 0;
}


/**
 * Safely read an index (idx_t) structure.
 *
 * @param[in] idx MEX input position index (0 is first).
 * @param[in] nrhs Number of right-hand sides.
 * @param[in] mxArray  MEX input array.
 * @param[out] idx_vec If function returns `1`, `idx_vec` contains a valid
 *                     index (idx_t) structure extracted from the MEX input,
 *                     otherwise `idx_vec` remains unchanged.
 *
 * @returns success of extraction.
 */

int
extract_idx (int idx, int nrhs, const mxArray *prhs[], idx_t* idx_vec)
{
  uint64_t *ui = NULL;
  if (extract_ui_vector (idx, nrhs, prhs, &ui, 2))
    {
      (*idx_vec).start = ui[0];
      (*idx_vec).end   = ui[1];
      mxFree (ui);
      if (is_valid (idx_vec))
        return 1;
      DBG_PRINTF ("Invalid index [%d:%d].\n", (*idx_vec).start, (*idx_vec).end);
    }
  DBG_PRINTF ("%s\n", "Failed.");
  return 0;
}


// Rounding mode translation
// =========================
//
// -1.0 = MPFR_RNDD: round toward minus infinity
//                   (roundTowardNegative in IEEE 754-2008).
//  0.0 = MPFR_RNDN: round to nearest, with the even rounding rule
//                   (roundTiesToEven in IEEE 754-2008); see details below.
//  1.0 = MPFR_RNDU: round toward plus infinity
//                   (roundTowardPositive in IEEE 754-2008).
//  2.0 = MPFR_RNDZ: round toward zero (roundTowardZero in IEEE 754-2008).
//  3.0 = MPFR_RNDA: round away from zero.


/**
 * Export MPFR rounding mode to `double`.
 *
 * @param[in] rnd MPFR rounding mode.
 *
 * @returns `double` representation of rounding mode.  In case of an invalid
 *          rounding mode `rnd`, `FP_NAN` is returned.
 */

double
export_rounding_mode (mpfr_rnd_t rnd)
{
  double d = FP_NAN;
  switch (rnd)
    {
      case MPFR_RNDD:
        d = -1.0;
        break;
      case MPFR_RNDN:
        d = 0.0;
        break;
      case MPFR_RNDU:
        d = 1.0;
        break;
      case MPFR_RNDZ:
        d = 2.0;
        break;
      case MPFR_RNDA:
        d = 3.0;
        break;
      default:
        DBG_PRINTF ("%s\n", "Failed.");
        d = FP_NAN;
        break;
    }
  return d;
}


/**
 * Safely read MPFR rounding mode from MEX input.
 *
 * @param[in] idx MEX input position index (0 is first).
 * @param[in] nrhs Number of right-hand sides.
 * @param[in] mxArray  MEX input array.
 * @param[out] rnd If function returns `1`, `rnd` contains the MPFR rounding
 *                 mode extracted from the MEX input, otherwise `rnd` remains
 *                 unchanged.
 *
 * @returns success of extraction.
 */

int
extract_rounding_mode (int idx, int nrhs, const mxArray *prhs[], mpfr_rnd_t *rnd)
{
  int64_t si = 0;
  if (extract_si (idx, nrhs, prhs, &si))
    {
      switch (si)
        {
          case -1:
            *rnd = MPFR_RNDD;
            return 1;
          case 0:
            *rnd = MPFR_RNDN;
            return 1;
          case 1:
            *rnd = MPFR_RNDU;
            return 1;
          case 2:
            *rnd = MPFR_RNDZ;
            return 1;
          case 3:
            *rnd = MPFR_RNDA;
            return 1;
          default:
            break;
        }
    }
  return 0;
}


/**
 * Safely read MPFR precision from MEX input.
 *
 * @param[in] idx MEX input position index (0 is first).
 * @param[in] nrhs Number of right-hand sides.
 * @param[in] mxArray  MEX input array.
 * @param[out] prec If function returns `1`, `prec` contains the MPFR precision
 *                  extracted from the MEX input, otherwise `prec` remains
 *                  unchanged.
 *
 * @returns success of extraction.
 */

int
extract_prec (int idx, int nrhs, const mxArray *prhs[], mpfr_prec_t *prec)
{
  uint64_t ui = 0;
  if (extract_ui (idx, nrhs, prhs, &ui) && (MPFR_PREC_MIN < ui)
      && (ui < MPFR_PREC_MAX))
    {
      *prec = (mpfr_prec_t) ui;
      return 1;
    }
  return 0;
}

// Dirty hack for MS Windows Matlab, as the used MinGW is outdated.
#if defined(MX_API_VER) && (defined(_WIN32) || defined(WIN32))
FILE *__cdecl __acrt_iob_func(unsigned index)
{
    return &(__iob_func()[index]);
}

typedef FILE *__cdecl (*_f__acrt_iob_func)(unsigned index);
_f__acrt_iob_func __MINGW_IMP_SYMBOL(__acrt_iob_func) = __acrt_iob_func;
#endif

#endif  // GMP_MPFR_INTERFACE_H_
