# Description:
#     This module implements a geometric shape descriptor for hand images using 
#     Cython for performance optimization. The approach combines interest point 
#     extraction (including convexity defects and Chetverikov corner detection),
#     and computes multiple distance-based shape functions such as:
#         - Distances from contour points to rectangle corners
#         - Distance to the centroid (center of mass)
#         - Distance to a rotated axis
#     These distances are normalized and visualized to describe the hand's shape.
#
#     The descriptor is designed to be rotation-aware and robust to noise, and
#     is used as part of a feature extraction pipeline for sign language or
#     gesture recognition systems.
#
#     Key features:
#         - Multithreaded distance calculation
#         - Normalization of geometric descriptors
#         - Visualization of shape function results
#         - Custom interest point filtering using Chetverikov’s method
#
# Usage:
#     Intended to be imported and used as part of a preprocessing pipeline
#     before training machine learning or deep learning models on hand shapes.
#
# Dependencies:
#     - Cython
#     - OpenCV (cv2)
#     - NumPy
#     - Mahotas (if using Zernike moments externally)
#
# Note:
#     This file must be compiled with Cython before use.
# ------------------------------------------------------------------------------




# cython: language_level=3
import os
import cv2
import numpy as np
import math
from concurrent.futures import ThreadPoolExecutor
from cython.parallel import prange

cimport cython
cimport numpy as np
from libc.math cimport fabs, acos, hypot

from libc.stdlib cimport malloc, free

cdef double PI = 3.141592653589793

# Cython-compatible Point class
cdef class Point:
    cdef public double X
    cdef public double Y

    def __init__(self, double x, double y):
        self.X = x
        self.Y = y

    @property
    def x(self):
        return self.X

    @property
    def y(self):
        return self.Y

    def __repr__(self):
        return f"Point({self.X}, {self.Y})"


cdef class SizeFunction:
    cdef public Point mc
    cdef public list rect_points
    cdef public str chemin
    cdef public str result_path

    def __cinit__(self):
        self.mc = Point(0, 0)
        self.rect_points = []

    cpdef void mainn(self, str imagefile, double ang, str result_path):
        self.chemin = imagefile
        self.result_path = result_path

        im = cv2.imread(imagefile, 0)
        if im is None:
            print("Failed to load image:", imagefile)
            return

        approx = self.ExtractionPointInteret(im)
        Distance = self.extractSize(approx, im, ang)

        angles = [-1, -2, -3, -4, -5, ang]
        with ThreadPoolExecutor(max_workers=6) as executor:
            for i, a in enumerate(angles):
                executor.submit(self.ExtractSizeGraph, i, "resultats/", len(approx), Distance, a)



    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef list Normalisation(self, object tab, double Min, double Max):
        cdef np.ndarray[np.float64_t, ndim=1] arr = np.array(tab, dtype=np.float64)
        cdef np.ndarray[np.float64_t, ndim=1] res = np.empty_like(arr)
        cdef double scale = 380.0 / (Max - Min + 1e-6)
        cdef int i
        for i in range(arr.shape[0]):
            res[i] = ((arr[i] - Min) * scale) + 10
        return res.tolist()

    cpdef Point NewXY(self, int x, int y, Point O):
        return Point(x - O.X, y - O.Y)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef int size_function(self, object tableau, double x, double y, int compt):
        cdef np.ndarray[np.float64_t, ndim=1] arr = np.array(tableau, dtype=np.float64)
        cdef int size = 0, j = -1, i, k
        for i in range(compt):
            if arr[i] < y and j == -1:
                j = i
            if arr[i] > y and j != -1:
                k = i
                while j < k and arr[j] > x:
                    j += 1
                if j < k:
                    size += 1
                    j = -1
        return size

    
    
    cpdef calc_distance_rect_points(self, Point rect_point, double[:, :] points, object normalisation_func):
        cdef int n = points.shape[0]
        cdef double[:] x = points[:, 0]
        cdef double[:] y = points[:, 1]
        cdef double[:] dists = np.empty(n, dtype=np.float64)

        cdef int i
        for i in range(n):
            dists[i] = hypot(x[i] - rect_point.X, y[i] - rect_point.Y)
        
        return normalisation_func(dists, np.min(dists), np.max(dists))



    cpdef calc_distance_mc(self, double[:, :] points, Point mc, object normalisation_func):
        cdef int n = points.shape[0]
        cdef double[:] x = points[:, 0]
        cdef double[:] y = points[:, 1]
        cdef double[:] dists = np.empty(n, dtype=np.float64)
        cdef int i

        for i in range(n):
            dists[i] = hypot(mc.x - x[i], mc.y - y[i])

        return normalisation_func(dists, np.min(dists), np.max(dists))

    cpdef calc_distance_with_angle(self, approx, Point mc, double tan_ang, double one_plus_tan_sq, object normalisation_func, object NewXY):
        cdef int n = len(approx)
        cdef double[:] dists = np.empty(n, dtype=np.float64)
        cdef int i
        cdef double x, y, dist
        cdef object p, temp_pt

        for i in range(n):
            p = approx[i]
            temp_pt = NewXY(p[0], p[1], mc)
            x = mc.X + (temp_pt.X + temp_pt.Y * tan_ang) / one_plus_tan_sq
            y = mc.Y + (tan_ang * (temp_pt.X + temp_pt.Y * tan_ang)) / one_plus_tan_sq
            dist = hypot(mc.X - x, mc.Y - y)
            dists[i] = dist

        return normalisation_func(dists, np.min(dists), np.max(dists))



    cdef object worker(self, tuple func_args):
        cdef object func = func_args[0]
        cdef tuple args = func_args[1]
        return func(*args)

    cpdef list extractSize(self, list approx, object im, double ang):
        cdef np.ndarray[np.float64_t, ndim=2] points = np.array([p for p in approx], dtype=np.float64)
        cdef double tan_ang = math.tan(ang)
        cdef double one_plus_tan_sq = 1.0 + tan_ang ** 2

        normalisation_func = self.Normalisation
        NewXY_func = self.NewXY
        mc = self.mc

        tasks = []
        for i in range(4):
            rect_point = self.rect_points[i]
            tasks.append((self.calc_distance_rect_points, (rect_point, points, normalisation_func)))
        tasks.append((self.calc_distance_mc, (points, mc, normalisation_func)))
        tasks.append((self.calc_distance_with_angle, (approx, mc, tan_ang, one_plus_tan_sq, normalisation_func, NewXY_func)))

        results = []
        with ThreadPoolExecutor() as executor:
            futures = [executor.submit(self.worker, task) for task in tasks]
            for future in futures:
                results.append(future.result())

        return results
            
    cpdef void ExtractSizeGraph(self, int Graphindice, str path, int longueur, list Distance, double ang):
        cdef list data = Distance[Graphindice]
        cdef double maxx = max(data)
        cdef double minn = min(data)
        cdef np.ndarray[np.uint8_t, ndim=3] image = np.zeros((400, 400, 3), dtype=np.uint8)
        cdef int ix, iy, res
        cdef double x, y

        cdef dict color_map = {
            1: (255, 255, 255), 2: (200, 200, 200), 3: (150, 150, 150),
            4: (100, 100, 80), 5: (50, 30, 50), 6: (255, 50, 0),
            7: (50, 80, 255), 8: (200, 100, 50), 9: (100, 255, 100),
            10: (150, 0, 0), 11: (0, 0, 200), 12: (50, 200, 150),
            13: (100, 0, 0), 14: (20, 50, 100), 15: (40, 150, 40)
        }

        y = maxx
        while y > minn:
            x = minn
            while x < y:
                ix, iy = int(x), int(400 - y)
                if 0 <= ix < 400 and 0 <= iy < 400:
                    res = self.size_function(data, x, y, longueur)
                    if 1 <= res <= 15:
                        image[iy, ix] = color_map[res]
                x += 1.0
            y -= 1.0

        cv2.imwrite(os.path.join(self.result_path, f"results{ang}.png"), image)

    cpdef list Chetverikov(self, np.ndarray cnts):
        cdef int d = 10
        cdef int d2 = 5
        cdef int alpha = 140
        cdef int i, length = cnts.shape[0]
        cdef list chetverikov = []
        cdef list cht = []
        cdef double a, b, c, h, beta
        cdef int x1, y1, x2, y2, x3, y3
        cdef np.ndarray p, p_pos, p_neg

        for i in range(d, length - d, d2):
            p = cnts[i][0]
            p_pos = cnts[i + d][0]
            p_neg = cnts[i - d][0]

            x1, y1 = p[0], p[1]
            x2, y2 = p_pos[0], p_pos[1]
            x3, y3 = p_neg[0], p_neg[1]

            a = hypot(x1 - x2, y1 - y2)
            b = hypot(x1 - x3, y1 - y3)
            c = hypot(x3 - x2, y3 - y2)

            if a * b != 0.0:
                h = fabs(a * a + b * b - c * c) / (2.0 * a * b)
                if h > 1.0:
                    h = 1.0
                beta = acos(h) * 180.0 / PI 
                if beta < alpha:
                    if chetverikov and hypot(chetverikov[-1][0] - x1, chetverikov[-1][1] - y1) < 10:
                        if cht[-1][1] > beta:
                            cht[-1] = ([ (x1, y1), beta ])
                            chetverikov[-1] = (x1, y1)
                    else:
                        chetverikov.append((x1, y1))
                        cht.append([ (x1, y1), beta ])
        return chetverikov

    cpdef list ExtractionPointInteret(self, np.ndarray im):
        cdef np.ndarray cnts
        cdef int x, y, w, h
        cdef list Defects = []
        cdef object hull, defects
        cdef int i, s, e, f, d
        cdef list Point_chetverikov, near_points = []
        cdef list PtInteret, PointsInteret
        cdef np.ndarray clr
        cdef double M00, M10, M01
        cdef int cx, cy

        # Step 1: Find contours
        cdef object contours, hierarchy
        contours, hierarchy = cv2.findContours(im, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        contours = list(contours)  # convert tuple to list

        if not contours:
            print("No contours found.")
            return []

        # Step 2: Merge all contours into one array
        cnts = np.vstack(contours)
 

        # Step 3: Bounding box rectangle points
        x, y, w, h = cv2.boundingRect(cnts)
        self.rect_points = [Point(x, y), Point(x + w, y), Point(x, y + h), Point(x + w, y + h)]

 

        # Step 5: Extract convexity defects
        hull = cv2.convexHull(cnts, returnPoints=False)
        if cnts is not None and hull is not None and cnts.shape[0] >= 4 and hull.shape[0] >= 3:
            try:
                defects = cv2.convexityDefects(cnts, hull)
                if defects is not None:
                    for i in range(defects.shape[0]):
                        s, e, f, d = defects[i, 0]
                        Defects.append(tuple(cnts[f][0]))
                else:
                    print("No convexity defects found.")
            except Exception:
                print(f"Error computing convexity defects: {e}")
        else:
            print("Contour or hull too small or malformed.")

         # Step 6: Chetverikov interest points (custom corner detection)
        Point_chetverikov = self.Chetverikov(cnts)

        # Step 7: Filter convexity defects close to Chetverikov points
        near_points = []
        for defect_pt in Defects:
            for chet_pt in Point_chetverikov:
                if np.linalg.norm(np.array(chet_pt) - np.array(defect_pt)) < 15:
                    near_points.append(defect_pt)

        PtInteret = [pt for pt in Defects if pt not in near_points]
        PtInteret.extend(Point_chetverikov)

        # Step 8: Remove duplicates
        PointsInteret = list(set(PtInteret))


        # Step 10: Compute centroid
        cdef dict M = cv2.moments(cnts)
        M00 = M['m00']
        M10 = M['m10']
        M01 = M['m01']
        if M00 != 0:
            cx = int(M10 / M00)
            cy = int(M01 / M00)
        else:
            cx, cy = 0, 0

        self.mc = Point(cx, cy)

        return PointsInteret