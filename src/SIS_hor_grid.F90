!> Set up grid and processor domains and a wide variety of metric terms
module SIS_hor_grid

! This file is a part of SIS2. See LICENSE.md for the license.

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
! SIS_hor_grid - sets up grid and processor domains and a wide variety of      !
!   metric terms in a way that is very similar to MOM6. - Robert Hallberg      !
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!

use MOM_hor_index, only : hor_index_type, hor_index_init
use MOM_domains, only : MOM_domain_type, get_domain_extent, compute_block_extent
use MOM_domains, only : MOM_domains_init, clone_MOM_domain
use MOM_error_handler, only : SIS_error=>MOM_error, FATAL, WARNING, SIS_mesg=>MOM_mesg
use MOM_file_parser, only : get_param, log_param, log_version, param_file_type
use MOM_unit_scaling, only : unit_scale_type

implicit none ; private

#include <SIS2_memory.h>

public :: set_hor_grid, SIS_hor_grid_end, set_derived_SIS_metrics, set_first_direction, isPointInCell

!> Describes the horizontal sea ice grid
type, public :: SIS_hor_grid_type
  type(MOM_domain_type), pointer :: Domain => NULL() !< Sea ice model domain
  type(MOM_domain_type), pointer :: Domain_aux => NULL() !< A non-symmetric auxiliary domain type.
  type(hor_index_type) :: HI !< Horizontal index ranges

  integer :: isc !< The start i-index of cell centers within the computational domain
  integer :: iec !< The end i-index of cell centers within the computational domain
  integer :: jsc !< The start j-index of cell centers within the computational domain
  integer :: jec !< The end j-index of cell centers within the computational domain

  integer :: isd !< The start i-index of cell centers within the data domain
  integer :: ied !< The end i-index of cell centers within the data domain
  integer :: jsd !< The start j-index of cell centers within the data domain
  integer :: jed !< The end j-index of cell centers within the data domain

  integer :: isg !< The start i-index of cell centers within the global domain
  integer :: ieg !< The end i-index of cell centers within the global domain
  integer :: jsg !< The start j-index of cell centers within the global domain
  integer :: jeg !< The end j-index of cell centers within the global domain

  integer :: IscB !< The start i-index of cell vertices within the computational domain
  integer :: IecB !< The end i-index of cell vertices within the computational domain
  integer :: JscB !< The start j-index of cell vertices within the computational domain
  integer :: JecB !< The end j-index of cell vertices within the computational domain

  integer :: IsdB !< The start i-index of cell vertices within the data domain
  integer :: IedB !< The end i-index of cell vertices within the data domain
  integer :: JsdB !< The start j-index of cell vertices within the data domain
  integer :: JedB !< The end j-index of cell vertices within the data domain

  integer :: IsgB !< The start i-index of cell vertices within the global domain
  integer :: IegB !< The end i-index of cell vertices within the global domain
  integer :: JsgB !< The start j-index of cell vertices within the global domain
  integer :: JegB !< The end j-index of cell vertices within the global domain

  integer :: isd_global !< The value of isd in the global index space (decomposition invariant).
  integer :: jsd_global !< The value of isd in the global index space (decomposition invariant).
  integer :: idg_offset !< The offset between the corresponding global and local i-indices.
  integer :: jdg_offset !< The offset between the corresponding global and local j-indices.
  logical :: symmetric  !< True if symmetric memory is used.

  logical :: nonblocking_updates  !< If true, non-blocking halo updates are
                                  !! allowed.  The default is .false. (for now).
  integer :: first_direction !< An integer that indicates which direction is to be updated first in
                             !! directionally split parts of the calculation.  This can be altered
                             !! during the course of the run via calls to set_first_direction.

  real ALLOCABLE_, dimension(NIMEM_,NJMEM_) :: &
    mask2dT, &   !< 0 for land points and 1 for ocean points on the h-grid [nondim].
    geoLatT, &   !< The geographic latitude at q points in degrees of latitude or m.
    geoLonT, &   !< The geographic longitude at q points in degrees of longitude or m.
    dxT, &       !< dxT is delta x at h points [L ~> m].
    IdxT, &      !< 1/dxT [L-1 ~> m-1].
    dyT, &       !< dyT is delta y at h points [L ~> m].
    IdyT, &      !< IdyT is 1/dyT [L-1 ~> m-1].
    areaT, &     !< The area of an h-cell [L2 ~> m2].
    IareaT       !< 1/areaT [L-2 ~> m-2].
  real ALLOCABLE_, dimension(NIMEM_,NJMEM_) :: sin_rot
                 !< The sine of the angular rotation between the local model grid northward
                 !! and the true northward directions.
  real ALLOCABLE_, dimension(NIMEM_,NJMEM_) :: cos_rot
                 !< The cosine of the angular rotation between the local model grid northward
                 !! and the true northward directions.

  real ALLOCABLE_, dimension(NIMEMB_PTR_,NJMEM_) :: &
    mask2dCu, &  !< 0 for boundary points and 1 for ocean points on the u grid [nondim].
    geoLatCu, &  !< The geographic latitude at u points in degrees of latitude or m.
    geoLonCu, &  !< The geographic longitude at u points in degrees of longitude or m.
    dxCu, &      !< dxCu is delta x at u points [L ~> m].
    IdxCu, &     !< 1/dxCu [L-1 ~> m-1].
    dyCu, &      !< dyCu is delta y at u points [L ~> m].
    IdyCu, &     !< 1/dyCu [L-1 ~> m-1].
    dy_Cu, &     !< The unblocked lengths of the u-faces of the h-cell [L ~> m].
    IareaCu, &   !< The masked inverse areas of u-grid cells [L-2 ~> m-2].
    areaCu       !< The areas of the u-grid cells [L2 ~> m2].

  real ALLOCABLE_, dimension(NIMEM_,NJMEMB_PTR_) :: &
    mask2dCv, &  !< 0 for boundary points and 1 for ocean points on the v grid [nondim].
    geoLatCv, &  !< The geographic latitude at v points in degrees of latitude or m.
    geoLonCv, &  !<  The geographic longitude at v points in degrees of longitude or m.
    dxCv, &      !< dxCv is delta x at v points [L ~> m].
    IdxCv, &     !< 1/dxCv [L-1 ~> m-1].
    dyCv, &      !< dyCv is delta y at v points [L ~> m].
    IdyCv, &     !< 1/dyCv [L-1 ~> m-1].
    dx_Cv, &     !< The unblocked lengths of the v-faces of the h-cell [L ~> m].
    IareaCv, &   !< The masked inverse areas of v-grid cells [L-2 ~> m-2].
    areaCv       !< The areas of the v-grid cells [L2 ~> m2].

  real ALLOCABLE_, dimension(NIMEMB_PTR_,NJMEMB_PTR_) :: &
    mask2dBu, &  !< 0 for boundary points and 1 for ocean points on the q grid [nondim].
    geoLatBu, &  !< The geographic latitude at q points in degrees of latitude or m.
    geoLonBu, &  !< The geographic longitude at q points in degrees of longitude or m.
    dxBu, &      !< dxBu is delta x at q points [L ~> m].
    IdxBu, &     !< 1/dxBu [L-1 ~> m-1].
    dyBu, &      !< dyBu is delta y at q points [L ~> m].
    IdyBu, &     !< 1/dyBu [L-1 ~> m-1].
    areaBu, &    !< areaBu is the area of a q-cell [L2 ~> m2]
    IareaBu      !< IareaBu = 1/areaBu [L-2 ~> m-2].

  real, pointer, dimension(:) :: gridLatT => NULL()
        !< The latitude of T points for the purpose of labeling the output axes.
        !! On many grids this is the same as geoLatT.
  real, pointer, dimension(:) :: gridLatB => NULL()
        !< The latitude of B points for the purpose of labeling the output axes.
        !! On many grids this is the same as geoLatBu.
  real, pointer, dimension(:) :: gridLonT => NULL()
        !< The longitude of T points for the purpose of labeling the output axes.
        !! On many grids this is the same as geoLonT.
  real, pointer, dimension(:) :: gridLonB => NULL()
        !< The longitude of B points for the purpose of labeling the output axes.
        !! On many grids this is the same as geoLonBu.
  character(len=40) :: &
    x_axis_units, &     !< The units that are used in labeling the x coordinate axes.
    y_axis_units        !< The units that are used in labeling the y coordinate axes.
    ! Except on a Cartesian grid, these are usually  some variant of "degrees".

  real ALLOCABLE_, dimension(NIMEM_,NJMEM_) :: &
    bathyT        !< Ocean bottom depth at tracer points [Z ~> m].
  real ALLOCABLE_, dimension(NIMEMB_PTR_,NJMEMB_PTR_) :: &
    CoriolisBu    !< The Coriolis parameter at corner points [T-1 ~> s-1].
  real ALLOCABLE_, dimension(NIMEM_,NJMEM_) :: &
    df_dx, &      !< Derivative d/dx f (Coriolis parameter) at h-points [T-1 L-1 ~> s-1 m-1].
    df_dy         !< Derivative d/dy f (Coriolis parameter) at h-points [T-1 L-1 ~> s-1 m-1].
  real :: g_Earth !<   The gravitational acceleration [L2 Z-1 T-2 ~> m s-2].

  type(unit_scale_type), pointer :: US => NULL() !< A dimensional unit scaling type

  ! These variables are for block structures.
  integer :: nblocks  !< The number of sub-PE blocks on this PE
  type(hor_index_type), pointer :: Block(:) => NULL() !< Index ranges for each block

  ! These parameters are run-time parameters that are used during some
  ! initialization routines (but not all)
  real :: south_lat     !< The latitude (or y-coordinate) of the first v-line
  real :: west_lon      !< The longitude (or x-coordinate) of the first u-line
  real :: len_lat = 0.  !< The latitudinal (or y-coord) extent of physical domain
  real :: len_lon = 0.  !< The longitudinal (or x-coord) extent of physical domain
  real :: Rad_Earth     !< The radius of the planet [L ~> m], by default 6.378e6 m
  real :: max_depth     !< The maximum depth of the ocean [m].
end type SIS_hor_grid_type

contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
!> set_hor_grid initializes the sea ice grid array sizes and grid memory.
subroutine set_hor_grid(G, param_file, HI, global_indexing)
  type(SIS_hor_grid_type), intent(inout) :: G        !< The horizontal grid type
  type(param_file_type), intent(in)    :: param_file !< Parameter file handle
  type(hor_index_type), &
                  optional, intent(in) :: HI !< A hor_index_type for array extents
  logical,        optional, intent(in) :: global_indexing !< If true use global index
                             !! values instead of having the data domain on each
                             !! processor start at 1.

! This include declares and sets the variable "version".
# include "version_variable.h"
  integer :: isd, ied, jsd, jed, nk
  integer :: IsdB, IedB, JsdB, JedB
  integer :: ied_max, jed_max
  integer :: niblock, njblock, nihalo, njhalo, nblocks, n, i, j
  logical :: local_indexing  ! If false use global index values instead of having
                             ! the data domain on each processor start at 1.

  integer, allocatable, dimension(:) :: ibegin, iend, jbegin, jend
  character(len=40)  :: mod_nm  = "hor_grid" ! The name of this module.

  ! Read all relevant parameters and write them to the model log.
  call log_version(param_file, mod_nm, version, &
                   "Parameters providing information about the lateral grid.")

  call get_param(param_file, mod_nm, "NIBLOCK", niblock, "The number of blocks "// &
                 "in the x-direction on each processor (for openmp).", default=1, &
                 layoutParam=.true.)
  call get_param(param_file, mod_nm, "NJBLOCK", njblock, "The number of blocks "// &
                 "in the y-direction on each processor (for openmp).", default=1, &
                 layoutParam=.true.)

  if (present(HI)) then
    G%HI = HI

    G%isc = HI%isc ; G%iec = HI%iec ; G%jsc = HI%jsc ; G%jec = HI%jec
    G%isd = HI%isd ; G%ied = HI%ied ; G%jsd = HI%jsd ; G%jed = HI%jed
    G%isg = HI%isg ; G%ieg = HI%ieg ; G%jsg = HI%jsg ; G%jeg = HI%jeg

    G%IscB = HI%IscB ; G%IecB = HI%IecB ; G%JscB = HI%JscB ; G%JecB = HI%JecB
    G%IsdB = HI%IsdB ; G%IedB = HI%IedB ; G%JsdB = HI%JsdB ; G%JedB = HI%JedB
    G%IsgB = HI%IsgB ; G%IegB = HI%IegB ; G%JsgB = HI%JsgB ; G%JegB = HI%JegB

    G%idg_offset = HI%idg_offset ; G%jdg_offset = HI%jdg_offset
    G%isd_global = G%isd + HI%idg_offset ; G%jsd_global = G%jsd + HI%jdg_offset
    G%symmetric = HI%symmetric
  else
    local_indexing = .true.
    if (present(global_indexing)) local_indexing = .not.global_indexing
    call hor_index_init(G%Domain, G%HI, param_file, &
                        local_indexing=local_indexing)

    ! get_domain_extent ensures that domains start at 1 for compatibility between
    ! static and dynamically allocated arrays, unless global_indexing is true.
    call get_domain_extent(G%Domain, G%isc, G%iec, G%jsc, G%jec, &
                           G%isd, G%ied, G%jsd, G%jed, &
                           G%isg, G%ieg, G%jsg, G%jeg, &
                           G%idg_offset, G%jdg_offset, G%symmetric, &
                           local_indexing=local_indexing)
    G%isd_global = G%isd+G%idg_offset ; G%jsd_global = G%jsd+G%jdg_offset
  endif

  G%nonblocking_updates = G%Domain%nonblocking_updates

  ! Set array sizes for fields that are discretized at tracer cell boundaries.
  G%IscB = G%isc ; G%JscB = G%jsc
  G%IsdB = G%isd ; G%JsdB = G%jsd
  G%IsgB = G%isg ; G%JsgB = G%jsg
  if (G%symmetric) then
    G%IscB = G%isc-1 ; G%JscB = G%jsc-1
    G%IsdB = G%isd-1 ; G%JsdB = G%jsd-1
    G%IsgB = G%isg-1 ; G%JsgB = G%jsg-1
  endif
  G%IecB = G%iec ; G%JecB = G%jec
  G%IedB = G%ied ; G%JedB = G%jed
  G%IegB = G%ieg ; G%JegB = G%jeg

  call SIS_mesg("  SIS_hor_grid.F90, set_hor_grid: allocating metrics", 5)

  call allocate_metrics(G)

! setup block indices.
  nihalo = G%Domain%nihalo
  njhalo = G%Domain%njhalo
  nblocks = niblock * njblock
  if (nblocks < 1) call SIS_error(FATAL, "SIS: set_hor_grid: " // &
       "nblocks(=NI_BLOCK*NJ_BLOCK) must be no less than 1")

  allocate(ibegin(niblock), iend(niblock), jbegin(njblock), jend(njblock))
  call compute_block_extent(G%HI%isc,G%HI%iec,niblock,ibegin,iend)
  call compute_block_extent(G%HI%jsc,G%HI%jec,njblock,jbegin,jend)
  !-- make sure the last block is the largest.
  do i = 1, niblock-1
    if (iend(i)-ibegin(i) > iend(niblock)-ibegin(niblock) ) call SIS_error(FATAL, &
       "SIS: set_hor_grid: the last block size in x-direction is not the largest")
  enddo
  do j = 1, njblock-1
    if (jend(j)-jbegin(j) > jend(njblock)-jbegin(njblock) ) call SIS_error(FATAL, &
       "SIS: set_hor_grid: the last block size in y-direction is not the largest")
  enddo

  G%nblocks = nblocks
  allocate(G%Block(nblocks))
  ied_max = 1 ; jed_max = 1
  do n = 1,nblocks
    ! Copy all information from the array index type describing the local grid.
    G%Block(n) = G%HI

    i = mod((n-1), niblock) + 1
    j = (n-1)/niblock + 1
    !--- isd and jsd are always 1 for each block to permit array reuse.
    G%Block(n)%isd = 1 ; G%Block(n)%jsd = 1
    G%Block(n)%isc = G%Block(n)%isd+nihalo
    G%Block(n)%jsc = G%Block(n)%jsd+njhalo
    G%Block(n)%iec = G%Block(n)%isc + iend(i) - ibegin(i)
    G%Block(n)%jec = G%Block(n)%jsc + jend(j) - jbegin(j)
    G%Block(n)%ied = G%Block(n)%iec + nihalo
    G%Block(n)%jed = G%Block(n)%jec + njhalo
    G%Block(n)%IscB = G%Block(n)%isc; G%Block(n)%IecB = G%Block(n)%iec
    G%Block(n)%JscB = G%Block(n)%jsc; G%Block(n)%JecB = G%Block(n)%jec
    !   For symmetric memory domains, the first block will have the extra point
    ! at the lower boundary of its computational domain.
    if (G%symmetric) then
      if (i==1) G%Block(n)%IscB = G%Block(n)%IscB-1
      if (j==1) G%Block(n)%JscB = G%Block(n)%JscB-1
    endif
    G%Block(n)%IsdB = G%Block(n)%isd; G%Block(n)%IedB = G%Block(n)%ied
    G%Block(n)%JsdB = G%Block(n)%jsd; G%Block(n)%JedB = G%Block(n)%jed
    !--- For symmetric memory domain, every block will have an extra point
    !--- at the lower boundary of its data domain.
    if (G%symmetric) then
      G%Block(n)%IsdB = G%Block(n)%IsdB-1
      G%Block(n)%JsdB = G%Block(n)%JsdB-1
    endif
    G%Block(n)%idg_offset = (ibegin(i) - G%Block(n)%isc) + G%HI%idg_offset
    G%Block(n)%jdg_offset = (jbegin(j) - G%Block(n)%jsc) + G%HI%jdg_offset
    ! Find the largest values of ied and jed so that all blocks will have the
    ! same size in memory.
    ied_max = max(ied_max, G%Block(n)%ied)
    jed_max = max(jed_max, G%Block(n)%jed)
  enddo

  ! Reset all of the data domain sizes to match the largest for array reuse,
  ! recalling that all block have isd=jed=1 for array reuse.
  do n = 1,nblocks
    G%Block(n)%ied = ied_max ; G%Block(n)%IedB = ied_max
    G%Block(n)%jed = jed_max ; G%Block(n)%JedB = jed_max
  enddo

  !-- do some bounds error checking
  if ( G%block(nblocks)%ied+G%block(nblocks)%idg_offset > G%HI%ied + G%HI%idg_offset ) &
        call SIS_error(FATAL, "SIS: set_hor_grid: G%ied_bk > G%ied")
  if ( G%block(nblocks)%jed+G%block(nblocks)%jdg_offset > G%HI%jed + G%HI%jdg_offset ) &
        call SIS_error(FATAL, "SIS: set_hor_grid: G%jed_bk > G%jed")

end subroutine set_hor_grid


!> set_derived_SIS_metrics calculates metric terms that are derived from other metrics.
subroutine set_derived_SIS_metrics(G)
  type(SIS_hor_grid_type), intent(inout) :: G !< The horizontal grid type
!    Various inverse grid spacings and derived areas are calculated within this
!  subroutine.
  integer :: i, j, isd, ied, jsd, jed
  integer :: IsdB, IedB, JsdB, JedB

  isd = G%isd ; ied = G%ied ; jsd = G%jsd ; jed = G%jed
  IsdB = G%IsdB ; IedB = G%IedB ; JsdB = G%JsdB ; JedB = G%JedB

  do j=jsd,jed ; do i=isd,ied
    if (G%dxT(i,j) < 0.0) G%dxT(i,j) = 0.0
    if (G%dyT(i,j) < 0.0) G%dyT(i,j) = 0.0
    G%IdxT(i,j) = Adcroft_reciprocal(G%dxT(i,j))
    G%IdyT(i,j) = Adcroft_reciprocal(G%dyT(i,j))
    G%IareaT(i,j) = Adcroft_reciprocal(G%areaT(i,j))
  enddo ; enddo

  do j=jsd,jed ; do I=IsdB,IedB
    if (G%dxCu(I,j) < 0.0) G%dxCu(I,j) = 0.0
    if (G%dyCu(I,j) < 0.0) G%dyCu(I,j) = 0.0
    G%IdxCu(I,j) = Adcroft_reciprocal(G%dxCu(I,j))
    G%IdyCu(I,j) = Adcroft_reciprocal(G%dyCu(I,j))
  enddo ; enddo

  do J=JsdB,JedB ; do i=isd,ied
    if (G%dxCv(i,J) < 0.0) G%dxCv(i,J) = 0.0
    if (G%dyCv(i,J) < 0.0) G%dyCv(i,J) = 0.0
    G%IdxCv(i,J) = Adcroft_reciprocal(G%dxCv(i,J))
    G%IdyCv(i,J) = Adcroft_reciprocal(G%dyCv(i,J))
  enddo ; enddo

  do J=JsdB,JedB ; do I=IsdB,IedB
    if (G%dxBu(I,J) < 0.0) G%dxBu(I,J) = 0.0
    if (G%dyBu(I,J) < 0.0) G%dyBu(I,J) = 0.0

    G%IdxBu(I,J) = Adcroft_reciprocal(G%dxBu(I,J))
    G%IdyBu(I,J) = Adcroft_reciprocal(G%dyBu(I,J))
    ! areaBu has usually been set to a positive area elsewhere.
    if (G%areaBu(I,J) <= 0.0) G%areaBu(I,J) = G%dxBu(I,J) * G%dyBu(I,J)
    G%IareaBu(I,J) =  Adcroft_reciprocal(G%areaBu(I,J))
  enddo ; enddo
end subroutine set_derived_SIS_metrics

!> Adcroft_reciprocal(x) = 1/x for |x|>0 or 0 for x=0.
function Adcroft_reciprocal(val) result(I_val)
  real, intent(in) :: val  !< The value being inverted.
  real :: I_val            !< The Adcroft reciprocal of val.

  I_val = 0.0 ; if (val /= 0.0) I_val = 1.0/val
end function Adcroft_reciprocal

!> Returns true if the coordinates (x,y) are within the h-cell (i,j)
logical function isPointInCell(G, i, j, x, y)
  type(SIS_hor_grid_type), intent(in) :: G !< Grid type
  integer,                 intent(in) :: i !< i index of cell to test
  integer,                 intent(in) :: j !< j index of cell to test
  real,                    intent(in) :: x !< x coordinate of point
  real,                    intent(in) :: y !< y coordinate of point

  ! Local variables
  real :: xNE, xNW, xSE, xSW, yNE, yNW, ySE, ySW
  real :: p0, p1, p2, p3, l0, l1, l2, l3
  ! This is a crude calculation that assume a geographic coordinate system
  isPointInCell = .false.
  xNE = G%geoLonBu(i  ,j  ) ; yNE = G%geoLatBu(i  ,j  )
  xNW = G%geoLonBu(i-1,j  ) ; yNW = G%geoLatBu(i-1,j  )
  xSE = G%geoLonBu(i  ,j-1) ; ySE = G%geoLatBu(i  ,j-1)
  xSW = G%geoLonBu(i-1,j-1) ; ySW = G%geoLatBu(i-1,j-1)
  if (x<min(xNE,xNW,xSE,xSW) .or. x>max(xNE,xNW,xSE,xSW) .or. &
      y<min(yNE,yNW,ySE,ySW) .or. y>max(yNE,yNW,ySE,ySW) ) then
    return ! Avoid the more complicated calculation
  endif
  l0 = (x-xSW)*(ySE-ySW) - (y-ySW)*(xSE-xSW)
  l1 = (x-xSE)*(yNE-ySE) - (y-ySE)*(xNE-xSE)
  l2 = (x-xNE)*(yNW-yNE) - (y-yNE)*(xNW-xNE)
  l3 = (x-xNW)*(ySW-yNW) - (y-yNW)*(xSW-xNW)

  p0 = sign(1., l0) ; if (l0 == 0.) p0=0.
  p1 = sign(1., l1) ; if (l1 == 0.) p1=0.
  p2 = sign(1., l2) ; if (l2 == 0.) p2=0.
  p3 = sign(1., l3) ; if (l3 == 0.) p3=0.

  if ( (abs(p0)+abs(p2)) + (abs(p1)+abs(p3)) == abs((p0+p2) + (p1+p3)) ) then
    isPointInCell=.true.
  endif
end function isPointInCell

!> Specify which direction to work on first in directionally split algorithms.
subroutine set_first_direction(G, y_first)
  type(SIS_hor_grid_type), intent(inout) :: G   !< The horizontal grid type
  integer, intent(in) :: y_first !< A flag indicating which direction to work on first
                                 !! in split algorithms. Even for x, odd for y.

  G%first_direction = y_first
end subroutine set_first_direction

!---------------------------------------------------------------------
!> Allocate memory used by the SIS_hor_grid_type and related structures.
subroutine allocate_metrics(G)
  type(SIS_hor_grid_type), intent(inout) :: G !< The horizontal grid type
  integer :: isd, ied, jsd, jed, IsdB, IedB, JsdB, JedB, isg, ieg, jsg, jeg

  ! This subroutine allocates the lateral elements of the SIS_hor_grid_type that
  ! are always used and zeros them out.

  isd = G%isd ; ied = G%ied ; jsd = G%jsd ; jed = G%jed
  IsdB = G%IsdB ; IedB = G%IedB ; JsdB = G%JsdB ; JedB = G%JedB
  isg = G%isg ; ieg = G%ieg ; jsg = G%jsg ; jeg = G%jeg

  ALLOC_(G%dxT(isd:ied,jsd:jed))       ; G%dxT(:,:) = 0.0
  ALLOC_(G%dxCu(IsdB:IedB,jsd:jed))    ; G%dxCu(:,:) = 0.0
  ALLOC_(G%dxCv(isd:ied,JsdB:JedB))    ; G%dxCv(:,:) = 0.0
  ALLOC_(G%dxBu(IsdB:IedB,JsdB:JedB))  ; G%dxBu(:,:) = 0.0
  ALLOC_(G%IdxT(isd:ied,jsd:jed))      ; G%IdxT(:,:) = 0.0
  ALLOC_(G%IdxCu(IsdB:IedB,jsd:jed))   ; G%IdxCu(:,:) = 0.0
  ALLOC_(G%IdxCv(isd:ied,JsdB:JedB))   ; G%IdxCv(:,:) = 0.0
  ALLOC_(G%IdxBu(IsdB:IedB,JsdB:JedB)) ; G%IdxBu(:,:) = 0.0

  ALLOC_(G%dyT(isd:ied,jsd:jed))       ; G%dyT(:,:) = 0.0
  ALLOC_(G%dyCu(IsdB:IedB,jsd:jed))    ; G%dyCu(:,:) = 0.0
  ALLOC_(G%dyCv(isd:ied,JsdB:JedB))    ; G%dyCv(:,:) = 0.0
  ALLOC_(G%dyBu(IsdB:IedB,JsdB:JedB))  ; G%dyBu(:,:) = 0.0
  ALLOC_(G%IdyT(isd:ied,jsd:jed))      ; G%IdyT(:,:) = 0.0
  ALLOC_(G%IdyCu(IsdB:IedB,jsd:jed))   ; G%IdyCu(:,:) = 0.0
  ALLOC_(G%IdyCv(isd:ied,JsdB:JedB))   ; G%IdyCv(:,:) = 0.0
  ALLOC_(G%IdyBu(IsdB:IedB,JsdB:JedB)) ; G%IdyBu(:,:) = 0.0

  ALLOC_(G%areaT(isd:ied,jsd:jed))       ; G%areaT(:,:) = 0.0
  ALLOC_(G%IareaT(isd:ied,jsd:jed))      ; G%IareaT(:,:) = 0.0
  ALLOC_(G%areaBu(IsdB:IedB,JsdB:JedB))  ; G%areaBu(:,:) = 0.0
  ALLOC_(G%IareaBu(IsdB:IedB,JsdB:JedB)) ; G%IareaBu(:,:) = 0.0

  ALLOC_(G%mask2dT(isd:ied,jsd:jed))      ; G%mask2dT(:,:) = 0.0
  ALLOC_(G%mask2dCu(IsdB:IedB,jsd:jed))   ; G%mask2dCu(:,:) = 0.0
  ALLOC_(G%mask2dCv(isd:ied,JsdB:JedB))   ; G%mask2dCv(:,:) = 0.0
  ALLOC_(G%mask2dBu(IsdB:IedB,JsdB:JedB)) ; G%mask2dBu(:,:) = 0.0
  ALLOC_(G%geoLatT(isd:ied,jsd:jed))      ; G%geoLatT(:,:) = 0.0
  ALLOC_(G%geoLatCu(IsdB:IedB,jsd:jed))   ; G%geoLatCu(:,:) = 0.0
  ALLOC_(G%geoLatCv(isd:ied,JsdB:JedB))   ; G%geoLatCv(:,:) = 0.0
  ALLOC_(G%geoLatBu(IsdB:IedB,JsdB:JedB)) ; G%geoLatBu(:,:) = 0.0
  ALLOC_(G%geoLonT(isd:ied,jsd:jed))      ; G%geoLonT(:,:) = 0.0
  ALLOC_(G%geoLonCu(IsdB:IedB,jsd:jed))   ; G%geoLonCu(:,:) = 0.0
  ALLOC_(G%geoLonCv(isd:ied,JsdB:JedB))   ; G%geoLonCv(:,:) = 0.0
  ALLOC_(G%geoLonBu(IsdB:IedB,JsdB:JedB)) ; G%geoLonBu(:,:) = 0.0

  ALLOC_(G%dx_Cv(isd:ied,JsdB:JedB))     ; G%dx_Cv(:,:) = 0.0
  ALLOC_(G%dy_Cu(IsdB:IedB,jsd:jed))     ; G%dy_Cu(:,:) = 0.0

  ALLOC_(G%areaCu(IsdB:IedB,jsd:jed))  ; G%areaCu(:,:) = 0.0
  ALLOC_(G%areaCv(isd:ied,JsdB:JedB))  ; G%areaCv(:,:) = 0.0
  ALLOC_(G%IareaCu(IsdB:IedB,jsd:jed)) ; G%IareaCu(:,:) = 0.0
  ALLOC_(G%IareaCv(isd:ied,JsdB:JedB)) ; G%IareaCv(:,:) = 0.0

  ALLOC_(G%bathyT(isd:ied, jsd:jed)) ; G%bathyT(:,:) = 0.0
  ALLOC_(G%CoriolisBu(IsdB:IedB, JsdB:JedB)) ; G%CoriolisBu(:,:) = 0.0
  ALLOC_(G%dF_dx(isd:ied, jsd:jed)) ; G%dF_dx(:,:) = 0.0
  ALLOC_(G%dF_dy(isd:ied, jsd:jed)) ; G%dF_dy(:,:) = 0.0

  ALLOC_(G%sin_rot(isd:ied,jsd:jed)) ; G%sin_rot(:,:) = 0.0
  ALLOC_(G%cos_rot(isd:ied,jsd:jed)) ; G%cos_rot(:,:) = 1.0

  allocate(G%gridLonT(isg:ieg), source=0.0)
  allocate(G%gridLonB(isg-1:ieg), source=0.0)
  allocate(G%gridLatT(jsg:jeg), source=0.0)
  allocate(G%gridLatB(jsg-1:jeg), source=0.0)

end subroutine allocate_metrics

!---------------------------------------------------------------------
!> Release memory used by the SIS_hor_grid_type and related structures.
subroutine SIS_hor_grid_end(G)
  type(SIS_hor_grid_type), intent(inout) :: G !< The horizontal grid type

  DEALLOC_(G%dxT)  ; DEALLOC_(G%dxCu)  ; DEALLOC_(G%dxCv)  ; DEALLOC_(G%dxBu)
  DEALLOC_(G%IdxT) ; DEALLOC_(G%IdxCu) ; DEALLOC_(G%IdxCv) ; DEALLOC_(G%IdxBu)

  DEALLOC_(G%dyT)  ; DEALLOC_(G%dyCu)  ; DEALLOC_(G%dyCv)  ; DEALLOC_(G%dyBu)
  DEALLOC_(G%IdyT) ; DEALLOC_(G%IdyCu) ; DEALLOC_(G%IdyCv) ; DEALLOC_(G%IdyBu)

  DEALLOC_(G%areaT)  ; DEALLOC_(G%IareaT)
  DEALLOC_(G%areaBu) ; DEALLOC_(G%IareaBu)
  DEALLOC_(G%areaCu) ; DEALLOC_(G%IareaCu)
  DEALLOC_(G%areaCv)  ; DEALLOC_(G%IareaCv)

  DEALLOC_(G%mask2dT)  ; DEALLOC_(G%mask2dCu)
  DEALLOC_(G%mask2dCv) ; DEALLOC_(G%mask2dBu)

  DEALLOC_(G%geoLatT)  ; DEALLOC_(G%geoLatCu)
  DEALLOC_(G%geoLatCv) ; DEALLOC_(G%geoLatBu)
  DEALLOC_(G%geoLonT)  ; DEALLOC_(G%geoLonCu)
  DEALLOC_(G%geoLonCv) ; DEALLOC_(G%geoLonBu)

  DEALLOC_(G%dx_Cv) ; DEALLOC_(G%dy_Cu)

  DEALLOC_(G%bathyT)  ; DEALLOC_(G%CoriolisBu)
  DEALLOC_(G%dF_dx)  ; DEALLOC_(G%dF_dy)
  DEALLOC_(G%sin_rot) ; DEALLOC_(G%cos_rot)

  deallocate(G%gridLonT) ; deallocate(G%gridLatT)
  deallocate(G%gridLonB) ; deallocate(G%gridLatB)

  deallocate(G%Domain%mpp_domain)
  deallocate(G%Domain)

end subroutine SIS_hor_grid_end

end module SIS_hor_grid
