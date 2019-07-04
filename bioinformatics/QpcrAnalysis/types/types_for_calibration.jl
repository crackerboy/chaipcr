## types_for_calibration.jl
##
## data types and constants for calibration experiments
##
## Author: Tom Price
## Date:   Dec 2018

import DataStructures.OrderedDict

# include("CalibData.jl")
# include("K4Deconv.jl")


# ## types

# ## Enum type for K matrix calculation
# ## used in deconv.jl
# @enum WellProc well_proc_mean well_proc_vec

# # used in normalize.jl
# struct Ccsc # channels_check_subset_composite
#     set             ::Vector ## channels
#     description     ::String
# end

## unused
# type CalibCalibOutput
#     ary2dcv_1       ::Array{Float_T,3}
#     mw_ary3_1       ::Array{Float_T,3}
#     k4dcv_2         ::K4Deconv
#     dcvd_ary3_1     ::Array{Float_T,3}
#     wva_data_2      ::OrderedDict{Symbol,OrderedDict{Int,AbstractVector}}
#     dcv_aw_ary3_1   ::Array{Float_T,3}
# end


## constants

## scaling factors
## used in calib.jl
const SCALING_FACTOR_deconv_vec = [1.0, 4.2]    ## used: [1, oneof(1, 2, 3.5, 8, 7, 5.6, 4.2)]
const SCALING_FACTOR_adj_w2wvaf = 3.7           ## used: 9e5, 1e5, 1.2e6, 3.0

## old pre-defined (predfd) step ids for calibration data
## used in normalize.jl
const oc_water_step_id_PREDFD = 2
const oc_signal_step_ids_PREDFD = OrderedDict(1 => 4, 2 => 4)

## mapping from factory to user dye data
## used in normalize.jl
## db_name_ = "20160406_chaipcr"
# const PRESET_calib_ids = OrderedDict(
#     "water" => 114,
#     "signal" => OrderedDict("FAM"=>115, "HEX"=>116, "JOE"=>117))
# const DYE2CHST = OrderedDict( ## mapping from dye to channel and step_id.
#     "FAM" => OrderedDict("channel"=>1, "step_id"=>266),
#     "HEX" => OrderedDict("channel"=>2, "step_id"=>268),
#     "JOE" => OrderedDict("channel"=>2, "step_id"=>270))
# const DYE2CHST_channels = Vector{Int}(unique(map(
#     dye_dict -> dye_dict["channel"],
#     values(DYE2CHST)
# ))) ## change type from Any to Int (8e-6 to 13e-6 sec on PC)
# const DYE2CHST_ccsc = Ccsc(DYE2CHST_channels, "all channels in the preset well-to-well variation data")

## process preset calibration data
## used in normalize.jl
## 4 groups
const DEFAULT_encgr = Array{Int,2}(0, 0)
## const DEFAULT_encgr = [0 1 0 1; 0 0 1 1] ## NTC, homo ch1, homo ch2, hetero
const DEFAULT_init_FACTORS = [1, 1, 1, 1] ## sometimes "hetero" may not have very high end-point fluo
const DEFAULT_apg_LABELS = ["ntc", "homo_1", "homo_2", "hetero", "unclassified"] ## [0 1 0 1; 0 0 1 1]
## const DEFAULT_apg_LABELS = ["hetero", "homo_2", "homo_1", "ntc", "unclassified"] ## [1 0 1 0; 1 1 0 0]

## constants used in deconv.jl
const INV_NOTE_PT2 =
    ": K matrix is singular, using `pinv` instead of `inv` to compute inverse matrix of K. " *
    "Deconvolution result may not be accurate. " *
    "This may be caused by using the same or a similar set of solutions in the steps for different dyes."

## set default calibration experiment (legacy)
# const calib_info_AIR = 0